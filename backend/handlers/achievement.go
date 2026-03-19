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

	if tag.RowsAffected() > 0 {
		fmt.Printf("🎉 User %s just unlocked Achievement ID: %d (15,000 Coins)!\n", userID, achievementID)
	}
}