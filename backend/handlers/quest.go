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

	// 🌟 1. โหลดโซนเวลาประเทศไทย (UTC+7)
	loc, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		// กันเหนียว กรณีเครื่องเซิร์ฟเวอร์ไม่มีข้อมูล Timezone 
		loc = time.FixedZone("UTC+7", 7*3600) 
	}

	var dueDate time.Time

	// 🌟 2. ลองแปลงแบบมีเวลาก่อน (เผื่ออนาคตแอปส่งเวลามาด้วย)
	dueDate, err = time.Parse(time.RFC3339, dueDateStr)
	if err != nil {
		// 🌟 3. ถ้าแอปส่งมาแค่วันที่ (เช่น "2026-03-18") 
		// คำสั่งนี้จะล็อกให้เป็น 00:00:00 ของเวลาไทยทันที!
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
	defer tx.Rollback(ctx) // ถ้าพังระหว่างทาง จะ Rollback ทุกอย่าง

	// 🌟 1.0 ตรวจสอบและหักตั๋ว (Item ID = 17) ก่อนทำอย่างอื่น 🌟
	var ticketQuantity int
	checkTicketQuery := `
		SELECT quantity 
		FROM public.collect 
		WHERE user_id = $1 AND item_id = 17 
		FOR UPDATE
	`
	// ค้นหาตั๋วในกระเป๋า
	err = tx.QueryRow(ctx, checkTicketQuery, userID).Scan(&ticketQuantity)
	if err != nil || ticketQuantity <= 0 {
		// ไม่มีตั๋วในตาราง หรือ มีแต่ค่า <= 0
		c.JSON(http.StatusBadRequest, gin.H{"error": "Not enough QUEST_TICKET to create a quest"})
		return
	}

	// หักตั๋ว 1 ใบ
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

	// 🌟 จัดการอัปโหลดรูปภาพขึ้น Cloudinary (หลังจากเช็คตั๋วผ่านแล้ว) 🌟
	var imageUrlPtr *string
	file, _, err := c.Request.FormFile("image") 
	
	if err == nil { 
		defer file.Close()

		cloudinaryURL := os.Getenv("CLOUDINARY_URL")
		if cloudinaryURL == "" {
			fmt.Println("❌ Error: CLOUDINARY_URL is missing in .env file")
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

	// 1.1 Insert ลงตาราง quests
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

	// 1.2 ผูกภารกิจนี้ให้คนที่สร้าง
	insertDoQuestQuery := `
		INSERT INTO public.do_quests (user_id, quest_id, status)
		VALUES ($1, $2, 'in_progress');
	`
	_, err = tx.Exec(ctx, insertDoQuestQuery, userID, questID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to assign quest to user"})
		return
	}

	// 1.3 บันทึกของรางวัลทั้งหมดลงตาราง receive 
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

	// ยืนยัน Transaction (บันทึกเควส + หักตั๋วเสร็จสมบูรณ์)
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

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Quest completed successfully",
		"rewards": responseRewards, // ส่งของที่ดึงได้กลับไปทั้งหมด
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