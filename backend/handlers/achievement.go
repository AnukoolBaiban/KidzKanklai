package handlers

import (
	"backend/configs"
	"context"
	"fmt"

	"github.com/google/uuid"
)

// CheckCoinAchievement จะถูกเรียกเมื่อผู้เล่นได้รับ Coin เพิ่ม
// currentCoins คือจำนวนเงินทั้งหมดที่ผู้เล่นมี "หลังจาก" บวกเพิ่มแล้ว
func CheckCoinAchievement(ctx context.Context, userID uuid.UUID) {
	const achievementID = 1
	const targetCoins = 15000

	// คิวรี่หาจำนวน Coin ปัจจุบัน (ItemID 20)
	var currentCoins int
	coinQuery := `SELECT quantity FROM public.collect WHERE user_id = $1 AND item_id = 20`
	err := configs.DB.QueryRow(ctx, coinQuery, userID).Scan(&currentCoins)

	// ถ้าหาไม่เจอ หรือเหรียญไม่ถึง ให้จบการทำงาน
	if err != nil || currentCoins < targetCoins {
		return
	}

	// ถ้าเหรียญถึงเป้า ให้บันทึก/อัปเดตลงตาราง attain
	attainQuery := `
		INSERT INTO public.attain (user_id, achievement_id, status, completed_date, reward_claimed)
		VALUES ($1, $2, 'completed', NOW(), false)
		ON CONFLICT (user_id, achievement_id) 
		DO UPDATE SET 
			status = 'completed',
			completed_date = NOW()
		WHERE public.attain.status != 'completed';
	`
	tag, err := configs.DB.Exec(ctx, attainQuery, userID, achievementID)
	if err != nil {
		fmt.Printf("❌ [CheckCoinAchievement] Failed to update achievement for user %s: %v\n", userID, err)
		return
	}

	// 🌟 ถ้า achievement ถูก unlock ใหม่จริงๆ (RowsAffected > 0) ให้สร้าง Notification ด้วย
	if tag.RowsAffected() > 0 {
		fmt.Printf("🎉 User %s just unlocked Achievement ID: %d (15,000 Coins)!\n", userID, achievementID)

		// ดึงชื่อและรูปของ achievement จาก database
		var achName string
		var achImagePtr *string
		achQuery := `SELECT name, image FROM public.achievements WHERE id = $1`
		achErr := configs.DB.QueryRow(ctx, achQuery, achievementID).Scan(&achName, &achImagePtr)

		achImage := "assets/images/icon/iconAchievement.png" // รูปสำรอง
		if achErr == nil && achImagePtr != nil && *achImagePtr != "" {
			achImage = *achImagePtr
		}

		// สร้าง Notification ใน goroutine เพื่อไม่ block
		go func(u uuid.UUID, name, image string) {
			CreateAchievementNotification(context.Background(), u, name, image)
		}(userID, achName, achImage)
	}
}

// CheckQuestAchievement — ตรวจสอบและ unlock achievement เมื่อทำ quest ครบ
// สามารถเรียกจาก quest handler เมื่อ quest complete สำเร็จ
func CheckQuestAchievement(ctx context.Context, userID uuid.UUID, achievementID int64, targetCount int, currentCount int, achievementName string) {
	if currentCount < targetCount {
		return
	}

	attainQuery := `
		INSERT INTO public.attain (user_id, achievement_id, status, completed_date, reward_claimed)
		VALUES ($1, $2, 'completed', NOW(), false)
		ON CONFLICT (user_id, achievement_id) 
		DO UPDATE SET 
			status = 'completed',
			completed_date = NOW()
		WHERE public.attain.status != 'completed';
	`
	tag, err := configs.DB.Exec(ctx, attainQuery, userID, achievementID)
	if err != nil {
		fmt.Printf("❌ [CheckQuestAchievement] Failed to update achievement %d for user %s: %v\n", achievementID, userID, err)
		return
	}

	if tag.RowsAffected() > 0 {
		fmt.Printf("🎉 User %s just unlocked Achievement ID: %d (%s)!\n", userID, achievementID, achievementName)

		// ดึงรูปของ achievement
		var achImagePtr *string
		achQuery := `SELECT image FROM public.achievements WHERE id = $1`
		achImage := "assets/images/icon/iconAchievement.png"
		if err := configs.DB.QueryRow(ctx, achQuery, achievementID).Scan(&achImagePtr); err == nil {
			if achImagePtr != nil && *achImagePtr != "" {
				achImage = *achImagePtr
			}
		}

		go func(u uuid.UUID, name, image string) {
			CreateAchievementNotification(context.Background(), u, name, image)
		}(userID, achievementName, achImage)
	}
}