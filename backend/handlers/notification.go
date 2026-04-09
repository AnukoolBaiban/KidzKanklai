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
		WHERE gn.user_id = $1
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
		DELETE FROM public.get_notifications
		WHERE user_id = $1 AND notification_id = $2
	`
	tag, err := configs.DB.Exec(ctx, query, userID, notifID)
	if err != nil {
		fmt.Printf("❌ [DeleteNotification] Error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete notification"})
		return
	}

	// ลบออกจากตารางหลักด้วยเลยเมื่อไม่มีเชื่อมโยง
	configs.DB.Exec(ctx, "DELETE FROM public.notifications WHERE id = $1", notifID)

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
	query := `DELETE FROM public.get_notifications WHERE user_id = $1`
	tag, err := configs.DB.Exec(ctx, query, userID)
	if err != nil {
		fmt.Printf("❌ [DeleteAllNotifications] Error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete all notifications"})
		return
	}

	// 🌟 พิเศษ: รีเซ็ต ID ให้กลับไปเริ่มที่ 1 ใหม่ (TRUNCATE TABLE ... RESTART IDENTITY)
	// ลบข้อมูลออกทั้งหมดแล้วเริ่มนับเลขใหม่ จะส่งผลเต็มประสิทธิภาพเมื่อเคลียร์การแจ้งเตือนทิ้งหมด
	_, errTruncate := configs.DB.Exec(ctx, "TRUNCATE TABLE public.notifications RESTART IDENTITY CASCADE")
	if errTruncate != nil {
		fmt.Printf("⚠️ [DeleteAllNotifications] Failed to reset ID sequence: %v\n", errTruncate)
	} else {
		fmt.Println("♻️ [DeleteAllNotifications] Notification ID sequence has been reset to 1")
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Deleted %d notifications and reset ID sequence to 1", tag.RowsAffected()),
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
