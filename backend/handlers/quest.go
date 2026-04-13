package handlers

import (
	"backend/configs"
	"context"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ------------------------------------------------------------------------
// 1. API: สร้างภารกิจ (CreateNormalQuest)
// ------------------------------------------------------------------------
// POST /quests/create
func CreateNormalQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	name := c.PostForm("name")
	detail := c.PostForm("detail")
	dueDateStr := c.PostForm("due_date")

	if name == "" || dueDateStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Name and Due Date are required"})
		return
	}

	loc, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		loc = time.FixedZone("UTC+7", 7*3600) 
	}

	var dueDate time.Time
	dueDate, err = time.Parse(time.RFC3339, dueDateStr)
	if err != nil {
		dueDate, err = time.ParseInLocation("2006-01-02", dueDateStr, loc)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid Due Date format. Use YYYY-MM-DD"})
			return
		}
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 1.0 ตรวจสอบตั๋ว (สร้างตัวแปร hasTicket มาเก็บสถานะว่ามีตั๋วหรือไม่)
	var ticketQuantity int
	hasTicket := true // ตั้งค่าเริ่มต้นว่ามีตั๋ว

	checkTicketQuery := `
		SELECT quantity 
		FROM public.collect 
		WHERE user_id = $1 AND item_id = 17 
		FOR UPDATE
	`
	err = tx.QueryRow(ctx, checkTicketQuery, userID).Scan(&ticketQuantity)
	if err != nil || ticketQuantity <= 0 {
		// 🌟 ถ้าไม่มีตั๋วหรือน้อยกว่า 0 ให้เปลี่ยนสถานะ แต่ "ไม่ Return Error กลับไป" เพื่อให้สร้างเควสต่อได้
		hasTicket = false
	}

	// 🌟 ถ้ามีตั๋ว ถึงจะทำการหักตั๋ว
	if hasTicket {
		updateTicketQuery := `
			UPDATE public.collect 
			SET quantity = quantity - 1 
			WHERE user_id = $1 AND item_id = 17
		`
		_, err = tx.Exec(ctx, updateTicketQuery, userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to consume QUEST_TICKET"})
			return
		}
	}

	var imageUrlPtr *string
	file, _, err := c.Request.FormFile("image") 
	
	if err == nil { 
		defer file.Close()
		cloudinaryURL := os.Getenv("CLOUDINARY_URL")
		if cloudinaryURL == "" {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Server configuration error"})
			return
		}
		cld, err := cloudinary.NewFromURL(cloudinaryURL)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to initialize Cloudinary"})
			return
		}
		resp, err := cld.Upload.Upload(ctx, file, uploader.UploadParams{
			Folder: "KidzKanKlai/quests", 
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload image"})
			return
		}
		url := resp.SecureURL 
		imageUrlPtr = &url
	}

	var detailPtr *string
	if detail != "" {
		detailPtr = &detail
	}

	var questID int64
	questType := "ทั่วไป" 

	insertQuestQuery := `
		INSERT INTO public.quests (name, detail, image, start_date, due_date, type)
		VALUES ($1, $2, $3, NOW(), $4, $5)
		RETURNING id;
	`
	err = tx.QueryRow(ctx, insertQuestQuery, name, detailPtr, imageUrlPtr, dueDate, questType).Scan(&questID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create quest"})
		return
	}

	insertDoQuestQuery := `
		INSERT INTO public.do_quests (user_id, quest_id, status)
		VALUES ($1, $2, 'in_progress');
	`
	_, err = tx.Exec(ctx, insertDoQuestQuery, userID, questID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to assign quest to user"})
		return
	}

	// 🌟 1.3 บันทึกของรางวัล (เฉพาะคนที่มีตั๋วเท่านั้นถึงจะได้ของรางวัล!)
	if hasTicket {
		insertReceiveQuery := `
			INSERT INTO public.receive (quest_id, item_id, quantity)
			VALUES ($1, $2, $3);
		`
		rewards := []struct {
			ItemID   int64
			Quantity int
		}{
			{ItemID: 20, Quantity: 1500}, // 💰 COIN
			{ItemID: 21, Quantity: 1},    // 🎟️ ENERGY_TICKET
			{ItemID: 22, Quantity: 100},  // 🟢 EXP (ID=22)
		}

		for _, reward := range rewards {
			_, err = tx.Exec(ctx, insertReceiveQuery, questID, reward.ItemID, reward.Quantity)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to insert rewards"})
				return
			}
		}
	}

	IncrementSystemQuestProgress(ctx, tx, userID, 10001)
	IncrementSystemQuestProgress(ctx, tx, userID, 10004)

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Normal quest created successfully",
		"quest_id": questID,
		"image_url": imageUrlPtr,
	})
}


// ------------------------------------------------------------------------
// 2. API: รับรางวัล (CompleteNormalQuest)
// ------------------------------------------------------------------------
type CompleteQuestInput struct {
	QuestID int64 `json:"quest_id" binding:"required"`
}

// POST /quests/complete
func CompleteNormalQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var input CompleteQuestInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input: quest_id is required"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 2.1 เช็คสถานะการทำภารกิจ
	var currentStatus *string
	checkQuery := `
		SELECT status FROM public.do_quests 
		WHERE user_id = $1 AND quest_id = $2 FOR UPDATE
	`
	err = tx.QueryRow(ctx, checkQuery, userID, input.QuestID).Scan(&currentStatus)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Quest not found for this user"})
		return
	}
	if currentStatus != nil && *currentStatus == "completed" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Quest already completed"})
		return
	}

	// 2.2 อัปเดตให้สำเร็จ
	updateQuestQuery := `UPDATE public.do_quests SET status = 'completed', completed_date = NOW() WHERE user_id = $1 AND quest_id = $2`
	_, err = tx.Exec(ctx, updateQuestQuery, userID, input.QuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update quest status"})
		return
	}

	// 🌟 ลบการแจ้งเตือนเตือนความจำ (ถ้ามี)
	deleteWarningsQuery := `
		DELETE FROM public.get_notifications gn
		USING public.notifications n
		WHERE gn.notification_id = n.id 
		  AND gn.user_id = $1 
		  AND n.type IN ($2, $3)
	`
	tx.Exec(ctx, deleteWarningsQuery, userID, fmt.Sprintf("quest_1d_%d", input.QuestID), fmt.Sprintf("quest_1h_%d", input.QuestID))

	// 🌟 2.3 ไปดึงข้อมูลของรางวัลแบบไดนามิกจากตาราง receive 🌟
	rewardQuery := `
		SELECT r.item_id, r.quantity, i.name, i.image 
		FROM public.receive r
		JOIN public.items i ON r.item_id = i.id
		WHERE r.quest_id = $1
	`
	rows, err := tx.Query(ctx, rewardQuery, input.QuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch rewards from database"})
		return
	}

	// ดึงใส่ Struct ชั่วคราวก่อน เพื่อป้องกัน Error 'conn busy'
	type tempReward struct {
		ItemID   int64
		Quantity int
		Name     string
		Image    string
	}
	var pendingRewards []tempReward

	for rows.Next() {
		var itemID int64
		var qty int
		var namePtr *string
		var imagePtr *string

		if err := rows.Scan(&itemID, &qty, &namePtr, &imagePtr); err == nil {
			name := "Unknown"
			if namePtr != nil { name = *namePtr }
			imageStr := "assets/images/item/default_item.png"
			if imagePtr != nil && *imagePtr != "" { imageStr = *imagePtr }

			pendingRewards = append(pendingRewards, tempReward{
				ItemID: itemID, Quantity: qty, Name: name, Image: imageStr,
			})
		}
	}
	rows.Close() // คืนสาย Connection

	// 🌟 2.4 วนลูปแจกของให้ตรงจุด (แยก EXP กับ Item) 🌟
	var responseRewards []map[string]interface{}
	
	for _, rw := range pendingRewards {
		if rw.ItemID == 22 {
			// 🟢 ถ้าเป็น EXP (ID=22) ให้บวกเข้าตาราง characters
			updateExpQuery := `UPDATE public.characters SET experience = experience + $1 WHERE user_id = $2`
			_, err = tx.Exec(ctx, updateExpQuery, rw.Quantity, userID)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add EXP to character"})
				return
			}
		} else {
			// 💰 ถ้าเป็นไอเทมอื่นๆ ให้ใส่ตาราง collect (กระเป๋า)
			upsertItemQuery := `
				INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
				VALUES ($1, $2, $3, NOW())
				ON CONFLICT (user_id, item_id)
				DO UPDATE SET quantity = public.collect.quantity + EXCLUDED.quantity, acquired_date = NOW();
			`
			_, err = tx.Exec(ctx, upsertItemQuery, userID, rw.ItemID, rw.Quantity)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to distribute items"})
				return
			}
		}

		// เตรียมข้อมูลส่งกลับให้ Flutter วาดรูป Popup
		responseRewards = append(responseRewards, map[string]interface{}{
			"name":  rw.Name,
			"added": rw.Quantity,
			"image": rw.Image,
		})
	}

	// 🌟 ทริกเกอร์เควสแนะนำ: บวก progress เมื่อสำเร็จเควสทั่วไป
	IncrementSystemQuestProgress(ctx, tx, userID, 20001) // แนะนำ: สำเร็จเควสทั่วไป
	IncrementSystemQuestProgress(ctx, tx, userID, 20003) // แนะนำ: สำเร็จเควสรูปแบบใดก็ได้

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	go func(u uuid.UUID) {
		CheckCoinAchievement(context.Background(), u)
	}(userID)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Quest completed successfully",
		"rewards": responseRewards,
	})
}

// ------------------------------------------------------------------------
// 3. API: ยอมแพ้ภารกิจ (CancelQuest)
// ------------------------------------------------------------------------
type CancelQuestInput struct {
	QuestID int64 `json:"quest_id" binding:"required"`
}

// POST /quests/cancel
func CancelQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var input CancelQuestInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input: quest_id is required"})
		return
	}

	ctx := context.Background()

	// 1. เช็คสถานะปัจจุบันก่อนว่าทำได้ไหม (ต้องเป็น in_progress ถึงจะยอมแพ้ได้)
	var currentStatus *string
	checkQuery := `
		SELECT status FROM public.do_quests 
		WHERE user_id = $1 AND quest_id = $2
	`
	err = configs.DB.QueryRow(ctx, checkQuery, userID, input.QuestID).Scan(&currentStatus)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Quest not found for this user"})
		return
	}

	if currentStatus != nil {
		if *currentStatus == "completed" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot cancel a completed quest"})
			return
		}
		if *currentStatus == "failed" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Quest is already failed or cancelled"})
			return
		}
	}

	// 2. อัปเดตสถานะให้เป็น 'failed'
	updateQuestQuery := `UPDATE public.do_quests SET status = 'failed' WHERE user_id = $1 AND quest_id = $2`
	_, err = configs.DB.Exec(ctx, updateQuestQuery, userID, input.QuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to cancel quest"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Quest cancelled successfully",
	})
}

// ------------------------------------------------------------------------
// 4. API: เริ่มภารกิจทันที (StartInstantQuest)
// ------------------------------------------------------------------------
type StartInstantQuestInput struct {
	Name            string `json:"name" binding:"required"`
	DurationMinutes int    `json:"duration_minutes" binding:"required"` // เช่น 60 สำหรับ 1 ชั่วโมง
}

// POST /quests/instant/start
func StartInstantQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var input StartInstantQuestInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 1. ตรวจสอบตั๋ว
	var ticketQuantity int
	hasTicket := true

	checkTicketQuery := `SELECT quantity FROM public.collect WHERE user_id = $1 AND item_id = 17 FOR UPDATE`
	err = tx.QueryRow(ctx, checkTicketQuery, userID).Scan(&ticketQuantity)
	if err != nil || ticketQuantity <= 0 {
		// 🌟 ถ้าไม่มีตั๋ว ให้สร้างได้แต่จะไม่ได้ของรางวัล
		hasTicket = false
	}

	// 🌟 ถ้ามีตั๋ว ถึงจะหัก
	if hasTicket {
		updateTicketQuery := `UPDATE public.collect SET quantity = quantity - 1 WHERE user_id = $1 AND item_id = 17`
		_, err = tx.Exec(ctx, updateTicketQuery, userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to consume ticket"})
			return
		}
	}

	now := time.Now()
	dueDate := now.Add(time.Duration(input.DurationMinutes) * time.Minute)

	var questID int64
	questType := "ทันที" 
	detail := fmt.Sprintf("กิจกรรมจับเวลา: %d นาที", input.DurationMinutes)

	insertQuestQuery := `
		INSERT INTO public.quests (name, detail, start_date, due_date, type)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id;
	`
	err = tx.QueryRow(ctx, insertQuestQuery, input.Name, detail, now, dueDate, questType).Scan(&questID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create instant quest"})
		return
	}

	insertDoQuestQuery := `INSERT INTO public.do_quests (user_id, quest_id, status) VALUES ($1, $2, 'in_progress');`
	_, err = tx.Exec(ctx, insertDoQuestQuery, userID, questID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to assign quest to user"})
		return
	}

	// 🌟 5. บันทึกของรางวัล (ทำเฉพาะคนที่มีตั๋ว!)
	if hasTicket {
		baseCoin := 2000
		baseExp := 120
		energyTicket := 1

		if input.DurationMinutes > 15 {
			extraIntervals := (input.DurationMinutes - 15) / 10
			baseCoin += extraIntervals * 20
			baseExp += extraIntervals * 1
		}

		insertReceiveQuery := `INSERT INTO public.receive (quest_id, item_id, quantity) VALUES ($1, $2, $3);`
		rewards := []struct {
			ItemID   int64
			Quantity int
		}{
			{ItemID: 20, Quantity: baseCoin},
			{ItemID: 21, Quantity: energyTicket},
			{ItemID: 22, Quantity: baseExp},
		}

		for _, reward := range rewards {
			_, err = tx.Exec(ctx, insertReceiveQuery, questID, reward.ItemID, reward.Quantity)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to insert rewards"})
				return
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Instant quest started",
		"quest_id": questID,
		"due_date": dueDate.Format(time.RFC3339),
	})
}

// ------------------------------------------------------------------------
// 5. API: ส่งภารกิจทันทีเมื่อหมดเวลา (CompleteInstantQuest)
// ------------------------------------------------------------------------
// POST /quests/instant/complete
func CompleteInstantQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var input CompleteQuestInput // ใช้ Struct เดียวกับ CompleteNormalQuest ได้
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 1. ดึงสถานะและเวลา Due Date ออกมาตรวจสอบ
	var currentStatus string
	var dueDate time.Time
	checkQuery := `
		SELECT dq.status, q.due_date 
		FROM public.do_quests dq
		JOIN public.quests q ON dq.quest_id = q.id
		WHERE dq.user_id = $1 AND dq.quest_id = $2 
		FOR UPDATE
	`
	err = tx.QueryRow(ctx, checkQuery, userID, input.QuestID).Scan(&currentStatus, &dueDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Quest not found"})
		return
	}

	if currentStatus != "in_progress" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Quest is not in progress"})
		return
	}

	// 🌟 2. ตรวจสอบว่าเวลาผ่านไปจนครบกำหนดหรือยัง (สำคัญมาก ป้องกันการโกง)
	// อนุโลมให้ยิง API ก่อนเวลาหมดได้ 5 วินาที ป้องกันปัญหาเวลาของ Server กับมือถือเดินไม่เท่ากัน
	if time.Now().Add(5 * time.Second).Before(dueDate) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Countdown is not finished yet"})
		return
	}

	// 3. อัปเดตสถานะเป็น completed
	updateQuestQuery := `UPDATE public.do_quests SET status = 'completed', completed_date = NOW() WHERE user_id = $1 AND quest_id = $2`
	_, err = tx.Exec(ctx, updateQuestQuery, userID, input.QuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update status"})
		return
	}

	// 4. แจกของรางวัล (ดึง Logic เดิมจาก CompleteNormalQuest มาใช้ได้เลย)
	rewardQuery := `
		SELECT r.item_id, r.quantity, i.name, i.image 
		FROM public.receive r
		JOIN public.items i ON r.item_id = i.id
		WHERE r.quest_id = $1
	`
	rows, _ := tx.Query(ctx, rewardQuery, input.QuestID)
	
	type tempReward struct {
		ItemID   int64
		Quantity int
		Name     string
		Image    string
	}
	var pendingRewards []tempReward

	for rows.Next() {
		var itemID int64
		var qty int
		var namePtr, imagePtr *string
		if err := rows.Scan(&itemID, &qty, &namePtr, &imagePtr); err == nil {
			name := "Unknown"
			if namePtr != nil { name = *namePtr }
			imageStr := "assets/images/item/default_item.png"
			if imagePtr != nil { imageStr = *imagePtr }
			pendingRewards = append(pendingRewards, tempReward{ItemID: itemID, Quantity: qty, Name: name, Image: imageStr})
		}
	}
	rows.Close()

	var responseRewards []map[string]interface{}
	for _, rw := range pendingRewards {
		if rw.ItemID == 22 {
			tx.Exec(ctx, `UPDATE public.characters SET experience = experience + $1 WHERE user_id = $2`, rw.Quantity, userID)
		} else {
			upsertQuery := `
				INSERT INTO public.collect (user_id, item_id, quantity, acquired_date) VALUES ($1, $2, $3, NOW())
				ON CONFLICT (user_id, item_id) DO UPDATE SET quantity = public.collect.quantity + EXCLUDED.quantity, acquired_date = NOW();
			`
			tx.Exec(ctx, upsertQuery, userID, rw.ItemID, rw.Quantity)
		}
		responseRewards = append(responseRewards, map[string]interface{}{"name": rw.Name, "added": rw.Quantity, "image": rw.Image})
	}

	// 🌟 ทริกเกอร์เควสระบบ: บวกความคืบหน้าเควส ID 10002 และ 10003 (สำเร็จเควสทันที)
	IncrementSystemQuestProgress(ctx, tx, userID, 10002)
	IncrementSystemQuestProgress(ctx, tx, userID, 10003)

	// 🌟 ทริกเกอร์เควสแนะนำ: บวก progress เมื่อสำเร็จเควสทันที
	IncrementSystemQuestProgress(ctx, tx, userID, 20002) // แนะนำ: สำเร็จเควสทันที
	IncrementSystemQuestProgress(ctx, tx, userID, 20003) // แนะนำ: สำเร็จเควสรูปแบบใดก็ได้

	tx.Commit(ctx)

	go func(u uuid.UUID) {
		CheckCoinAchievement(context.Background(), u)
	}(userID)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Instant quest completed",
		"rewards": responseRewards,
	})
}

// POST /quests/system/init
func InitSystemQuests(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	ctx := context.Background()

	// ====================================================================
	// 🌟 STEP 0A: อัปเดต start_date / due_date ในตาราง quests
	//             สำหรับเควสระบบ (10001–10004)
	//             เมื่อ start_date อยู่ใน ISO week ที่แล้ว → ตั้งค่าใหม่ให้ตรงกับสัปดาห์ปัจจุบัน
	//             (ตาราง quests เป็น Global — ไม่ต้องระบุ user_id)
	// ====================================================================
	updateSystemDatesQuery := `
		UPDATE public.quests
		SET
			start_date = DATE_TRUNC('week', NOW()),
			due_date   = DATE_TRUNC('week', NOW()) + INTERVAL '6 days 17 hours'
		WHERE
			id IN (10001, 10002, 10003, 10004)
			AND (
				-- start_date อยู่ใน ISO week ที่แล้ว หรือเก่ากว่า → อัปเดต
				EXTRACT(ISOYEAR FROM start_date) < EXTRACT(ISOYEAR FROM NOW())
				OR (
					EXTRACT(ISOYEAR FROM start_date) = EXTRACT(ISOYEAR FROM NOW())
					AND EXTRACT(WEEK  FROM start_date) < EXTRACT(WEEK FROM NOW())
				)
			);
	`
	_, err = configs.DB.Exec(ctx, updateSystemDatesQuery)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update system quest dates"})
		return
	}

	// ====================================================================
	// 🌟 STEP 0B: อัปเดต start_date / due_date ในตาราง quests
	//             สำหรับเควสแนะนำ (20001–20003)
	//             เมื่อ start_date อยู่ใน ISO week ที่แล้ว → ตั้งค่าใหม่
	// ====================================================================
	updateRecommendedDatesQuery := `
		UPDATE public.quests
		SET
			start_date = DATE_TRUNC('week', NOW()),
			due_date   = DATE_TRUNC('week', NOW()) + INTERVAL '6 days 17 hours'
		WHERE
			id IN (20001, 20002, 20003)
			AND (
				EXTRACT(ISOYEAR FROM start_date) < EXTRACT(ISOYEAR FROM NOW())
				OR (
					EXTRACT(ISOYEAR FROM start_date) = EXTRACT(ISOYEAR FROM NOW())
					AND EXTRACT(WEEK  FROM start_date) < EXTRACT(WEEK FROM NOW())
				)
			);
	`
	_, err = configs.DB.Exec(ctx, updateRecommendedDatesQuery)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update recommended quest dates"})
		return
	}

	// ====================================================================
	// 🌟 STEP 1: รีเซ็ตรายสัปดาห์ (สำหรับเควสระบบ 10001–10004)
	// ถ้าเควสระบบที่ completed_date อยู่ในสัปดาห์ที่แล้ว → รีเซ็ตเป็น in_progress ใหม่
	// ====================================================================
	resetSystemQuery := `
		UPDATE public.do_quests
		SET 
			status        = 'in_progress',
			progress      = 0,
			completed_date = NULL
		WHERE 
			user_id  = $1
			AND quest_id IN (10001, 10002, 10003, 10004)
			AND status   = 'completed'
			AND (
				-- completed_date อยู่ใน ISO week ที่แล้ว (หรือเก่ากว่านั้น)
				EXTRACT(ISOYEAR FROM completed_date) < EXTRACT(ISOYEAR FROM NOW())
				OR (
					EXTRACT(ISOYEAR FROM completed_date) = EXTRACT(ISOYEAR FROM NOW())
					AND EXTRACT(WEEK  FROM completed_date) < EXTRACT(WEEK FROM NOW())
				)
			);
	`
	_, err = configs.DB.Exec(ctx, resetSystemQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset system quests"})
		return
	}

	// ====================================================================
	// 🌟 STEP 1.5: ตรวจเช็คว่าเควสระบบ (10001–10004) สำเร็จครบหรือยัง
	// ถ้ายัง "ไม่ครบ" → ลบภารกิจแนะนำ (20001–20003) ออกจาก do_quests
	// เพื่อป้องกันกรณีที่ระบบรีเซ็ต แต่ภารกิจแนะนำยังค้างอยู่
	// ====================================================================
	removeRecommendedIfIncompleteQuery := `
		DELETE FROM public.do_quests
		WHERE
			user_id  = $1
			AND quest_id IN (20001, 20002, 20003)
			AND NOT EXISTS (
				-- เช็คว่ามีเควสระบบที่ completed ครบ 4 ตัวหรือยัง
				SELECT 1
				FROM (
					SELECT COUNT(*) AS done
					FROM public.do_quests
					WHERE user_id = $1
						AND quest_id IN (10001, 10002, 10003, 10004)
						AND status = 'completed'
				) sub
				WHERE sub.done >= 4
			);
	`
	_, err = configs.DB.Exec(ctx, removeRecommendedIfIncompleteQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to validate recommended quest eligibility"})
		return
	}

	// ====================================================================
	// 🌟 STEP 2: รีเซ็ตรายสัปดาห์ (สำหรับเควสแนะนำ 20001–20003)
	// ถ้าเควสแนะนำที่ completed_date อยู่ในสัปดาห์ที่แล้ว → ลบออกจาก do_quests
	// เพื่อให้ CheckAndInitRecommendedQuest สามารถเลือก variant ใหม่ให้ได้
	// ====================================================================
	resetRecommendedQuery := `
		DELETE FROM public.do_quests
		WHERE 
			user_id  = $1
			AND quest_id IN (20001, 20002, 20003)
			AND status   = 'completed'
			AND (
				EXTRACT(ISOYEAR FROM completed_date) < EXTRACT(ISOYEAR FROM NOW())
				OR (
					EXTRACT(ISOYEAR FROM completed_date) = EXTRACT(ISOYEAR FROM NOW())
					AND EXTRACT(WEEK  FROM completed_date) < EXTRACT(WEEK FROM NOW())
				)
			);
	`
	_, err = configs.DB.Exec(ctx, resetRecommendedQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset recommended quests"})
		return
	}

	// ====================================================================
	// 🌟 STEP 3: ใช้ ON CONFLICT DO NOTHING:
	// ถ้ายังไม่มีเควสระบบ จะทำการสร้างให้ (progress=0)
	// ถ้ามีอยู่แล้ว คำสั่งนี้จะไม่ทำอะไรเลย (ไม่ไปทับ progress เดิม)
	// ====================================================================
	initQuery := `
		INSERT INTO public.do_quests (user_id, quest_id, status, progress)
		VALUES 
			($1, 10001, 'in_progress', 0),
			($1, 10002, 'in_progress', 0),
			($1, 10003, 'in_progress', 0),
			($1, 10004, 'in_progress', 0)
		ON CONFLICT (user_id, quest_id) DO NOTHING;
	`
	_, err = configs.DB.Exec(ctx, initQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to init system quests"})
		return
	}

	// ====================================================================
	// 🌟 STEP 4: เช็คและเปิดใช้งานภารกิจแนะนำ
	// (ถ้าทำเควสระบบครบแล้ว และยังไม่มีเควสแนะนำ active อยู่)
	// ใช้ ON CONFLICT DO NOTHING เหมือนกัน — เรียกซ้ำกี่ครั้งก็ปลอดภัย
	// ====================================================================
	go func(u uuid.UUID) {
		CheckAndInitRecommendedQuest(context.Background(), u)
	}(userID)

	c.JSON(http.StatusOK, gin.H{"success": true})
}


// ------------------------------------------------------------------------
// 6. API: รับรางวัลเควสระบบ (CompleteSystemQuest)
// ------------------------------------------------------------------------
// POST /quests/system/complete
func CompleteSystemQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var input CompleteQuestInput // ใช้ Struct เดียวกับเควสปกติได้เลย (รับแค่ quest_id)
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 1. ดึงสถานะ, ความคืบหน้า และเป้าหมาย ออกมาตรวจสอบก่อนแจกของ
	var currentStatus string
	var progress, targetAmount int
	checkQuery := `
		SELECT dq.status, dq.progress, q.target_amount
		FROM public.do_quests dq
		JOIN public.quests q ON dq.quest_id = q.id
		WHERE dq.user_id = $1 AND dq.quest_id = $2 AND q.type IN ('ระบบ', 'แนะนำ')
		FOR UPDATE
	`
	err = tx.QueryRow(ctx, checkQuery, userID, input.QuestID).Scan(&currentStatus, &progress, &targetAmount)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "System quest not found"})
		return
	}

	// 1.1 เช็คว่าเคยกดรับไปแล้วหรือยัง
	if currentStatus == "completed" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Reward already claimed for this week"})
		return
	}

	// 1.2 เช็คว่าทำถึงเป้าหรือยัง (ป้องกันการยิง API โกงเอาของรางวัล)
	if progress < targetAmount {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Quest requirements not met yet"})
		return
	}

	// 🌟 2. อัปเดตสถานะเป็น completed (แปลว่ารับรางวัลแล้ว)
	updateQuestQuery := `UPDATE public.do_quests SET status = 'completed', completed_date = NOW() WHERE user_id = $1 AND quest_id = $2`
	_, err = tx.Exec(ctx, updateQuestQuery, userID, input.QuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update status"})
		return
	}

	// 🌟 3. แจกของรางวัล (ดึง Logic แจกของเหมือนเดิมมาใช้)
	rewardQuery := `
		SELECT r.item_id, r.quantity, i.name, i.image 
		FROM public.receive r
		JOIN public.items i ON r.item_id = i.id
		WHERE r.quest_id = $1
	`
	rows, err := tx.Query(ctx, rewardQuery, input.QuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch rewards"})
		return
	}
	
	type tempReward struct {
		ItemID   int64
		Quantity int
		Name     string
		Image    string
	}
	var pendingRewards []tempReward

	for rows.Next() {
		var itemID int64
		var qty int
		var namePtr, imagePtr *string
		if err := rows.Scan(&itemID, &qty, &namePtr, &imagePtr); err == nil {
			name := "Unknown"
			if namePtr != nil { name = *namePtr }
			imageStr := "assets/images/item/default_item.png"
			if imagePtr != nil { imageStr = *imagePtr }
			pendingRewards = append(pendingRewards, tempReward{ItemID: itemID, Quantity: qty, Name: name, Image: imageStr})
		}
	}
	rows.Close()

	var responseRewards []map[string]interface{}
	for _, rw := range pendingRewards {
		if rw.ItemID == 22 { // สมมติว่า 22 คือ EXP
			tx.Exec(ctx, `UPDATE public.characters SET experience = experience + $1 WHERE user_id = $2`, rw.Quantity, userID)
		} else {
			upsertQuery := `
				INSERT INTO public.collect (user_id, item_id, quantity, acquired_date) VALUES ($1, $2, $3, NOW())
				ON CONFLICT (user_id, item_id) DO UPDATE SET quantity = public.collect.quantity + EXCLUDED.quantity, acquired_date = NOW();
			`
			tx.Exec(ctx, upsertQuery, userID, rw.ItemID, rw.Quantity)
		}
		responseRewards = append(responseRewards, map[string]interface{}{"name": rw.Name, "added": rw.Quantity, "image": rw.Image})
	}

	tx.Commit(ctx)

	go func(u uuid.UUID) {
		CheckCoinAchievement(context.Background(), u)
	}(userID)

	// 🌟 ตรวจสอบและเปิดใช้งานภารกิจแนะนำ เมื่อผู้เล่นทำเควสระบบครบแล้ว
	go func(u uuid.UUID) {
		CheckAndInitRecommendedQuest(context.Background(), u)
	}(userID)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "System quest reward claimed",
		"rewards": responseRewards,
	})
}

// ------------------------------------------------------------------------
// 🌟 Helper Function: อัปเดตความคืบหน้าเควสระบบ (Progress)
// ------------------------------------------------------------------------
func IncrementSystemQuestProgress(ctx context.Context, tx pgx.Tx, userID uuid.UUID, questID int64) error {
	// อัปเดต Progress + 1 เฉพาะเควสที่สถานะยังเป็น in_progress (ถ้ากดรับรางวัลไปแล้วจะได้ไม่บวกเพิ่ม)
	query := `
		UPDATE public.do_quests 
		SET progress = progress + 1 
		WHERE user_id = $1 AND quest_id = $2 AND status = 'in_progress';
	`
	_, err := tx.Exec(ctx, query, userID, questID)
	if err != nil {
		fmt.Printf("❌ Failed to increment progress for quest %d: %v\n", questID, err)
	}
	return err
}

// ------------------------------------------------------------------------
// 🌟 ฟังก์ชันตรวจสอบและเปิดใช้งานภารกิจแนะนำ (CheckAndInitRecommendedQuest)
// เรียกใน goroutine หลังจาก CompleteSystemQuest สำเร็จ
// จะ insert do_quests สำหรับ quest 20001/20002/20003 ตามพฤติกรรมผู้เล่น
// ------------------------------------------------------------------------
func CheckAndInitRecommendedQuest(ctx context.Context, userID uuid.UUID) {
	// 1. ตรวจสอบว่าผู้เล่นทำเควสระบบ 10001–10004 ครบทั้งหมดแล้วหรือยัง
	var completedCount int
	countQuery := `
		SELECT COUNT(*) 
		FROM public.do_quests 
		WHERE user_id = $1 AND quest_id IN (10001, 10002, 10003, 10004) AND status = 'completed'
	`
	err := configs.DB.QueryRow(ctx, countQuery, userID).Scan(&completedCount)
	if err != nil || completedCount < 4 {
		return // ยังทำเควสระบบไม่ครบ ยังไม่แสดงภารกิจแนะนำ
	}

	// 2. ตรวจสอบว่าผู้เล่นได้รับภารกิจแนะนำไปแล้วหรือยัง (ป้องกัน duplicate)
	var existingCount int
	existsQuery := `
		SELECT COUNT(*) 
		FROM public.do_quests 
		WHERE user_id = $1 AND quest_id IN (20001, 20002, 20003)
	`
	err = configs.DB.QueryRow(ctx, existsQuery, userID).Scan(&existingCount)
	if err != nil || existingCount > 0 {
		return // ได้รับภารกิจแนะนำไปแล้ว
	}

	// 3. นับจำนวนเควสที่ผู้เล่นสำเร็จแต่ละประเภท (ทั่วไป vs ทันที) ไม่รวมเควสระบบ
	var normalCount, instantCount int
	statsQuery := `
		SELECT 
			COUNT(CASE WHEN q.type = 'ทั่วไป' THEN 1 END),
			COUNT(CASE WHEN q.type = 'ทันที' THEN 1 END)
		FROM public.do_quests dq
		JOIN public.quests q ON dq.quest_id = q.id
		WHERE dq.user_id = $1 AND dq.status = 'completed' AND q.type IN ('ทั่วไป', 'ทันที')
	`
	err = configs.DB.QueryRow(ctx, statsQuery, userID).Scan(&normalCount, &instantCount)
	if err != nil {
		fmt.Printf("❌ CheckAndInitRecommendedQuest: Failed to count quests: %v\n", err)
		return
	}

	// 4. เลือก variant ตามพฤติกรรม
	// - instantCount > normalCount → แนะนำให้ทำเควสทั่วไปมากขึ้น (quest 20001)
	// - normalCount > instantCount → แนะนำให้ทำเควสทันทีมากขึ้น  (quest 20002)
	// - เท่ากัน                  → สำเร็จรูปแบบใดก็ได้            (quest 20003)
	var recommendedQuestID int64
	switch {
	case instantCount > normalCount:
		recommendedQuestID = 20001 // แนะนำ: สำเร็จเควสทั่วไป 5 ครั้ง
	case normalCount > instantCount:
		recommendedQuestID = 20002 // แนะนำ: สำเร็จเควสทันที 5 ครั้ง
	default:
		recommendedQuestID = 20003 // แนะนำ: สำเร็จเควสรูปแบบใดก็ได้ 5 ครั้ง
	}

	// 5. บันทึกภารกิจแนะนำลง do_quests
	insertQuery := `
		INSERT INTO public.do_quests (user_id, quest_id, status, progress)
		VALUES ($1, $2, 'in_progress', 0)
		ON CONFLICT (user_id, quest_id) DO NOTHING;
	`
	_, err = configs.DB.Exec(ctx, insertQuery, userID, recommendedQuestID)
	if err != nil {
		fmt.Printf("❌ CheckAndInitRecommendedQuest: Failed to insert quest %d: %v\n", recommendedQuestID, err)
		return
	}

	fmt.Printf("✅ Recommended quest %d assigned to user %s (normal=%d, instant=%d)\n",
		recommendedQuestID, userID, normalCount, instantCount)
}

