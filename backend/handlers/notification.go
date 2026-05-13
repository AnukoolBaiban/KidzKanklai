package handlers

import (
	"backend/configs"
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// NotificationResponse — struct ที่ส่งกลับให้ Flutter
type NotificationResponse struct {
	ID        int64      `json:"id"`
	Title     string     `json:"title"`
	Detail    string     `json:"detail"`
	Type      string     `json:"type"`
	Image     string     `json:"image"`
	StartDate time.Time  `json:"start_date"`
	DueDate   time.Time  `json:"due_date"`
	Status    string     `json:"status"`
	ReadDate  *time.Time `json:"read_date"`
}

// GET /notifications — ดึง Notification ทั้งหมดของ user + auto-delete รายการที่เกิน 30 วัน
func GetNotifications(c *gin.Context) {
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

	// 🌟 ประมวลผลแจ้งเตือนภารกิจที่กำลังจะหมดเวลาหรือหมดเวลาแล้ว
	ProcessQuestNotifications(ctx, userID)

	// 1. ลบ Notification ที่เกิน DueDate ทิ้งจากระบบ
	// ลบการเชื่อมโยงออกก่อน
	deleteOldLinksQuery := `
		DELETE FROM public.get_notifications gn
		USING public.notifications n
		WHERE gn.notification_id = n.id
		  AND n.due_date <= NOW()
	`
	configs.DB.Exec(ctx, deleteOldLinksQuery)

	// ตามด้วยลบในตาราง notifications หลัก
	deleteOldQuery := `
		DELETE FROM public.notifications
		WHERE due_date <= NOW()
	`
	deletedTag, err := configs.DB.Exec(ctx, deleteOldQuery)
	if err != nil {
		fmt.Printf("⚠️ [GetNotifications] Failed to delete expired notifications: %v\n", err)
	} else if deletedTag.RowsAffected() > 0 {
		fmt.Printf("🗑️ [GetNotifications] Auto-deleted %d expired notifications\n", deletedTag.RowsAffected())
	}

	// 2. ดึง Notification ที่เหลือ (join กัน)
	query := `
		SELECT 
			n.id,
			COALESCE(n.title, ''),
			COALESCE(n.detail, ''),
			COALESCE(n.type, ''),
			COALESCE(n.image, ''),
			COALESCE(n.start_date, NOW()),
			COALESCE(n.due_date, (CURRENT_DATE + INTERVAL '6 days') + TIME '17:00:00'),
			COALESCE(gn.status, 'unread'),
			gn.read_date
		FROM public.get_notifications gn
		JOIN public.notifications n ON gn.notification_id = n.id
		WHERE gn.user_id = $1 AND gn.status != 'deleted'
		ORDER BY n.start_date DESC
	`
	rows, err := configs.DB.Query(ctx, query, userID)
	if err != nil {
		fmt.Printf("❌ [GetNotifications] Query error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch notifications"})
		return
	}
	defer rows.Close()

	var notifications []NotificationResponse
	for rows.Next() {
		var n NotificationResponse
		if err := rows.Scan(
			&n.ID,
			&n.Title,
			&n.Detail,
			&n.Type,
			&n.Image,
			&n.StartDate,
			&n.DueDate,
			&n.Status,
			&n.ReadDate,
		); err != nil {
			fmt.Printf("⚠️ [GetNotifications] Row scan error: %v\n", err)
			continue
		}
		notifications = append(notifications, n)
	}

	if notifications == nil {
		notifications = []NotificationResponse{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"notifications": notifications,
		"count":         len(notifications),
	})
}

// PUT /notifications/:id/read — Mark notification ว่าอ่านแล้ว
func MarkNotificationRead(c *gin.Context) {
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

	notifIDStr := c.Param("id")
	notifID, err := strconv.ParseInt(notifIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	ctx := context.Background()
	query := `
		UPDATE public.get_notifications
		SET status = 'read', read_date = NOW()
		WHERE user_id = $1 AND notification_id = $2
	`
	tag, err := configs.DB.Exec(ctx, query, userID, notifID)
	if err != nil {
		fmt.Printf("❌ [MarkNotificationRead] Error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark as read"})
		return
	}

	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Marked as read"})
}

// DELETE /notifications/:id — ลบ Notification รายการเดียว (ลบออก get_notifications, ไม่ลบตาราง notifications)
func DeleteNotification(c *gin.Context) {
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

	notifIDStr := c.Param("id")
	notifID, err := strconv.ParseInt(notifIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	ctx := context.Background()
	query := `
		UPDATE public.get_notifications
		SET status = 'deleted'
		WHERE user_id = $1 AND notification_id = $2
	`
	tag, err := configs.DB.Exec(ctx, query, userID, notifID)
	if err != nil {
		fmt.Printf("❌ [DeleteNotification] Error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete notification"})
		return
	}

	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Notification deleted"})
}

// DELETE /notifications — ลบ Notification ทั้งหมดของ user
func DeleteAllNotifications(c *gin.Context) {
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
	query := `UPDATE public.get_notifications SET status = 'deleted' WHERE user_id = $1`
	tag, err := configs.DB.Exec(ctx, query, userID)
	if err != nil {
		fmt.Printf("❌ [DeleteAllNotifications] Error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete all notifications"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Deleted %d notifications", tag.RowsAffected()),
	})
}

// CreateAchievementNotification — สร้าง Notification เมื่อ unlock achievement
// เรียกจาก achievement.go เมื่อ achievement ถูก unlock สำเร็จ
func CreateAchievementNotification(ctx context.Context, userID uuid.UUID, achievementName string, achievementImage string) {
	// คำนวณ due_date (อีก 6 วัน เวลา 17:00:00)
	now := time.Now()
	dueDate := time.Date(now.Year(), now.Month(), now.Day()+6, 24, 0, 0, 0, now.Location())

	// 1. Insert เข้า notifications table
	var notifID int64
	insertNotifQuery := `
		INSERT INTO public.notifications (title, detail, type, image, start_date, due_date)
		VALUES ($1, $2, 'achievement', $3, NOW(), $4)
		RETURNING id
	`
	title := "ปลดล็อกความสำเร็จใหม่! 🏆"
	detail := fmt.Sprintf("ยินดีด้วย! คุณปลดล็อก \"%s\" สำเร็จแล้ว! เข้าไปที่หน้าความสำเร็จเพื่อรับรางวัลได้เลย", achievementName)

	err := configs.DB.QueryRow(ctx, insertNotifQuery, title, detail, achievementImage, dueDate).Scan(&notifID)
	if err != nil {
		fmt.Printf("❌ [CreateAchievementNotification] Failed to insert notification: %v\n", err)
		return
	}

	// 2. Insert เข้า get_notifications เพื่อเชื่อมกับ user
	linkQuery := `
		INSERT INTO public.get_notifications (user_id, notification_id, status, read_date, reward_claimed)
		VALUES ($1, $2, 'unread', NULL, false)
		ON CONFLICT (user_id, notification_id) DO NOTHING
	`
	_, err = configs.DB.Exec(ctx, linkQuery, userID, notifID)
	if err != nil {
		fmt.Printf("❌ [CreateAchievementNotification] Failed to link user-notification: %v\n", err)
		return
	}

	fmt.Printf("🔔 [CreateAchievementNotification] Created notification ID %d for user %s (Achievement: %s)\n", notifID, userID, achievementName)
}

// CreateClubKickNotification — สร้าง Notification เมื่อถูกไล่ออกจากชมรม
func CreateClubKickNotification(ctx context.Context, tx pgx.Tx, userID uuid.UUID, clubName string) {
	now := time.Now()
	// กำหนดวันหมดอายุเป็น 6 วันข้างหน้า เวลา 17:00
	dueDate := time.Date(now.Year(), now.Month(), now.Day()+6, 17, 0, 0, 0, now.Location())

	var notifID int64
	insertNotifQuery := `
		INSERT INTO public.notifications (title, detail, type, image, start_date, due_date)
		VALUES ($1, $2, 'club_kick', 'assets/images/icon/club-detail.png', NOW(), $3)
		RETURNING id
	`
	title := "คุณพ้นสภาพสมาชิกชมรม 🛡️"
	detail := fmt.Sprintf("คุณถูกหัวหน้าชมรมปลดออกจากชมรม \"%s\" แล้ว คุณสามารถเลือกเข้าร่วมชมรมอื่นๆ ได้ตามต้องการ", clubName)

	err := tx.QueryRow(ctx, insertNotifQuery, title, detail, dueDate).Scan(&notifID)
	if err != nil {
		fmt.Printf("❌ [CreateClubKickNotification] Failed to insert notification: %v\n", err)
		return
	}

	linkQuery := `
		INSERT INTO public.get_notifications (user_id, notification_id, status, read_date, reward_claimed)
		VALUES ($1, $2, 'unread', NULL, false)
		ON CONFLICT (user_id, notification_id) DO NOTHING
	`
	_, err = tx.Exec(ctx, linkQuery, userID, notifID)
	if err != nil {
		fmt.Printf("❌ [CreateClubKickNotification] Failed to link user-notification: %v\n", err)
		return
	}

	fmt.Printf("🔔 [CreateClubKickNotification] Created notification ID %d for user %s (Club: %s)\n", notifID, userID, clubName)
}

// ProcessQuestNotifications ตรวจสอบและสร้างการแจ้งเตือนสำหรับภารกิจที่กำลังจะหมดเวลาหรือหมดเวลาแล้ว
func ProcessQuestNotifications(ctx context.Context, userID uuid.UUID) {
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		return
	}
	defer tx.Rollback(ctx)

	// ใช้ advisory lock เพื่อป้องกัน Race Condition ระหว่างหลาย Request ของ user คนเดียวกัน
	_, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock(hashtext($1::text))", userID.String())
	if err != nil {
		return
	}

	query := `
		SELECT dq.quest_id, q.name, q.due_date 
		FROM public.do_quests dq
		JOIN public.quests q ON dq.quest_id = q.id
		WHERE dq.user_id = $1 AND dq.status = 'in_progress' AND q.type = 'ทั่วไป'
	`
	rows, err := tx.Query(ctx, query, userID)
	if err != nil {
		return
	}
	
	type activeQuest struct {
		ID      int64
		Name    string
		DueDate time.Time
	}
	var quests []activeQuest
	for rows.Next() {
		var q activeQuest
		if err := rows.Scan(&q.ID, &q.Name, &q.DueDate); err == nil {
			quests = append(quests, q)
		}
	}
	rows.Close()

	if len(quests) == 0 {
		return
	}

	// ตรวจสอบประเภทที่เคยแจ้งเตือนไปแล้ว (เช็ครวมถึง status 'deleted' เพื่อไม่ให้เด้งซ้ำ)
	notifQuery := `
		SELECT n.type 
		FROM public.notifications n
		JOIN public.get_notifications gn ON n.id = gn.notification_id
		WHERE gn.user_id = $1 AND n.type LIKE 'quest_%'
	`
	rNotif, err := tx.Query(ctx, notifQuery, userID)
	sentTypes := make(map[string]bool)
	if err == nil {
		for rNotif.Next() {
			var t string
			rNotif.Scan(&t)
			sentTypes[t] = true
		}
		rNotif.Close()
	}

	now := time.Now()
	// บังคับกำหนดให้ due_date ของการแจ้งเตือน เป็นเวลา 17.00 ของอีก 6 วันข้างหน้า
	notifDueDate := time.Date(now.Year(), now.Month(), now.Day()+6, 17, 0, 0, 0, now.Location())

	for _, q := range quests {
		remainingHours := q.DueDate.Sub(now).Hours()

		if remainingHours <= 0 {
			// Failed!
			tx.Exec(ctx, "UPDATE public.do_quests SET status = 'failed' WHERE user_id = $1 AND quest_id = $2", userID, q.ID)
			
			typeKey := fmt.Sprintf("quest_fail_%d", q.ID)
			if !sentTypes[typeKey] {
				createQuestNotificationTx(ctx, tx, userID, "ภารกิจล้มเหลว ❌", fmt.Sprintf("หมดเวลาทำภารกิจ '%s' แล้ว ไว้รอบหน้าลองใหม่นะ", q.Name), typeKey, notifDueDate)
			}
		} else if remainingHours <= 1 {
			// 1 hour
			typeKey := fmt.Sprintf("quest_1h_%d", q.ID)
			if !sentTypes[typeKey] {
				createQuestNotificationTx(ctx, tx, userID, "เหลือเวลาไม่ถึง 1 ชั่วโมง! ⏳", fmt.Sprintf("ภารกิจ '%s' ใกล้จะหมดเวลาทำภารกิจแล้ว รีบหน่อยนะ!", q.Name), typeKey, notifDueDate)
			}
		} else if remainingHours <= 24 {
			// 1 day
			typeKey := fmt.Sprintf("quest_1d_%d", q.ID)
			if !sentTypes[typeKey] {
				createQuestNotificationTx(ctx, tx, userID, "เหลือเวลาไม่ถึง 1 วัน! ⏰", fmt.Sprintf("อย่าลืมทำภารกิจ '%s' นะ เหลือเวลาอีกไม่มากแล้ว", q.Name), typeKey, notifDueDate)
			}
		}
	}

	tx.Commit(ctx)
}

func createQuestNotificationTx(ctx context.Context, tx pgx.Tx, userID uuid.UUID, title, detail, notifType string, dueDate time.Time) {
	imgArg := "assets/images/icon/iconQuest.png"

	// 1. Insert เข้า notifications table (ใช้ CTE ป้องกัน Race Condition)
	var notifID int64
	insertNotifQuery := `
		WITH new_notif AS (
			INSERT INTO public.notifications (title, detail, type, image, start_date, due_date)
			SELECT $1, $2, $3, $4, NOW(), $5
			WHERE NOT EXISTS (SELECT 1 FROM public.notifications WHERE type = $3)
			RETURNING id
		)
		SELECT id FROM new_notif
		UNION ALL
		SELECT id FROM public.notifications WHERE type = $3
		LIMIT 1;
	`
	err := tx.QueryRow(ctx, insertNotifQuery, title, detail, notifType, imgArg, dueDate).Scan(&notifID)
	if err != nil {
		fmt.Printf("❌ [createQuestNotificationTx] Failed to insert/find notification: %v\n", err)
		return
	}

	// 2. Insert เข้า get_notifications เพื่อเชื่อมกับ user
	linkQuery := `
		INSERT INTO public.get_notifications (user_id, notification_id, status, read_date, reward_claimed)
		VALUES ($1, $2, 'unread', NULL, false)
		ON CONFLICT (user_id, notification_id) DO NOTHING
	`
	_, err = tx.Exec(ctx, linkQuery, userID, notifID)
	if err != nil {
		fmt.Printf("❌ [createQuestNotificationTx] Failed to link user-notification: %v\n", err)
	}
}

// POST /notifications/:id/claim — กดรับของรางวัลจากจดหมาย
func ClaimNotificationReward(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, _ := uuid.Parse(userIDStr)

	notifIDStr := c.Param("id")
	notifID, err := strconv.ParseInt(notifIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 1. เช็คว่ามีจดหมายนี้อยู่จริง และยังไม่ได้กดรับ
	var isClaimed bool
	err = tx.QueryRow(ctx, `SELECT COALESCE(reward_claimed, false) FROM public.get_notifications WHERE user_id = $1 AND notification_id = $2 FOR UPDATE`, userID, notifID).Scan(&isClaimed)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "ไม่พบการแจ้งเตือนนี้"})
		return
	}
	if isClaimed {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณรับของรางวัลนี้ไปแล้ว"})
		return
	}

	// 🌟 2. ดึงของรางวัลจากตาราง obtain (ใช้ COALESCE ป้องกัน quantity เป็น NULL)
	rows, err := tx.Query(ctx, `
		SELECT o.item_id, COALESCE(o.quantity, 1), COALESCE(i.name, 'Item'), COALESCE(i.image, '') 
		FROM public.obtain o
		JOIN public.items i ON o.item_id = i.id
		WHERE o.notification_id = $1
	`, notifID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ดึงข้อมูลของรางวัลล้มเหลว"})
		return
	}

	// ดึงข้อมูลมาเก็บใน Struct ชั่วคราวก่อน เพื่อหลีกเลี่ยงการเปิด rows ค้างไว้แล้วไปทำ Query ซ้อน
	type rewardItem struct {
		ItemID int64
		Qty    int
		Name   string
		Image  string
	}
	var pendingRewards []rewardItem

	for rows.Next() {
		var itemID int64
		var qty int
		var name, image string
		if err := rows.Scan(&itemID, &qty, &name, &image); err == nil {
			pendingRewards = append(pendingRewards, rewardItem{ItemID: itemID, Qty: qty, Name: name, Image: image})
		}
	}
	rows.Close() // ปิด connection เพื่อความปลอดภัย

	var rewards []map[string]interface{}

	// 🌟 3. ยัดของเข้าตัว (แก้ปัญหา Database Constraints)
	for _, item := range pendingRewards {
		if item.ItemID == 22 || item.Name == "EXP" {
			// อัปเดต EXP
			_, errExp := tx.Exec(ctx, `UPDATE public.characters SET experience = experience + $1 WHERE user_id = $2`, item.Qty, userID)
			if errExp != nil {
				fmt.Println("❌ [Claim Reward] Update EXP Error:", errExp)
			}
		} else {
			// 🌟 ใช้ SELECT ตรวจสอบก่อนว่ามีของชิ้นนี้อยู่แล้วหรือยัง ปลอดภัยกว่าการใช้ ON CONFLICT
			var exists int
			errCheck := tx.QueryRow(ctx, "SELECT 1 FROM public.collect WHERE user_id = $1 AND item_id = $2", userID, item.ItemID).Scan(&exists)
			
			if errCheck != nil {
				// หาไม่เจอ แปลว่ายังไม่เคยมีของชิ้นนี้ ให้ INSERT
				_, errCol := tx.Exec(ctx, `
					INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
					VALUES ($1, $2, $3, NOW())
				`, userID, item.ItemID, item.Qty)
				if errCol != nil {
					fmt.Println("❌ [Claim Reward] Insert Collect Error:", errCol)
				}
			} else {
				// ถ้ามีแล้ว ให้อัปเดตบวกเพิ่ม
				_, errCol := tx.Exec(ctx, `
					UPDATE public.collect 
					SET quantity = quantity + $1, acquired_date = NOW() 
					WHERE user_id = $2 AND item_id = $3
				`, item.Qty, userID, item.ItemID)
				if errCol != nil {
					fmt.Println("❌ [Claim Reward] Update Collect Error:", errCol)
				}
			}
		}

		rewards = append(rewards, map[string]interface{}{
			"item_id": item.ItemID,
			"name":    item.Name,
			"amount":  item.Qty, // ชื่อฟิลด์ส่งกลับแอปต้องเป็น amount ตามที่ Flutter รอรับ
			"image":   item.Image,
		})
	}

	// 4. อัปเดตสถานะว่ารับแล้ว ทั้งใน obtain และ get_notifications
	tx.Exec(ctx, `UPDATE public.obtain SET reward_claimed = true, completed_date = NOW() WHERE notification_id = $1`, notifID)
	tx.Exec(ctx, `UPDATE public.get_notifications SET reward_claimed = true, status = 'read', read_date = NOW() WHERE user_id = $1 AND notification_id = $2`, userID, notifID)

	// 🌟 5. ยืนยันการเปลี่ยนแปลง (ถ้าพัง ให้โยน Error 500 โชว์ Flutter ทันที)
	if err := tx.Commit(ctx); err != nil {
		fmt.Println("❌ [Claim Reward] Transaction Commit Error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "เกิดข้อผิดพลาดในการบันทึกข้อมูลลงฐานข้อมูล"})
		return
	}

	// 🌟 6. ยืนยันเซฟลง DB เสร็จแล้ว ค่อยเรียกเช็ค Achievement (เพื่อป้องกันการคิวรี่ขัดจังหวะ Transaction)
	go func(u uuid.UUID) {
		CheckCoinAchievement(context.Background(), u)
	}(userID)
	CheckLevelAchievement(context.Background(), userID)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "รับรางวัลสำเร็จ!",
		"rewards": rewards,
	})
}

// GET /notifications/:id/rewards — ดึงข้อมูลของรางวัลและสถานะการรับของจดหมาย
func GetNotificationRewards(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, _ := uuid.Parse(userIDStr)

	notifIDStr := c.Param("id")
	notifID, err := strconv.ParseInt(notifIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	ctx := context.Background()

	// 1. เช็คสถานะ reward_claimed
	var isClaimed bool
	err = configs.DB.QueryRow(ctx, `SELECT COALESCE(reward_claimed, false) FROM public.get_notifications WHERE user_id = $1 AND notification_id = $2`, userID, notifID).Scan(&isClaimed)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "ไม่พบการแจ้งเตือน"})
		return
	}

	// 2. ดึงลิสต์ของรางวัลจาก obtain
	rows, err := configs.DB.Query(ctx, `
		SELECT o.item_id, COALESCE(o.quantity, 1), COALESCE(i.name, 'Item'), COALESCE(i.image, '') 
		FROM public.obtain o
		JOIN public.items i ON o.item_id = i.id
		WHERE o.notification_id = $1
	`, notifID)
	
	var rewards []map[string]interface{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var itemID int64
			var qty int
			var name, image string
			rows.Scan(&itemID, &qty, &name, &image)
			rewards = append(rewards, map[string]interface{}{
				"item_id": itemID,
				"name":    name,
				"amount":  qty,
				"image":   image,
			})
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"is_claimed": isClaimed,
		"rewards":    rewards,
	})
}
