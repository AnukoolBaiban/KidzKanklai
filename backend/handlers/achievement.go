package handlers

import (
	"backend/configs"
	"context"
	"fmt"

	"github.com/google/uuid"
)

// CheckCoinAchievement จะถูกเรียกเมื่อผู้เล่นได้รับ Coin เพิ่ม
// currentCoins คือจำนวนเงินทั้งหมดที่ผู้เล่นมี "หลังจาก" บวกเพิ่มแล้ว
func CheckCoinAchievement(userID uuid.UUID, currentCoins int) {
	// ⚠️ กำหนด ID ของ Achievement "มี Coin ครบ 15,000" ให้ตรงกับในตาราง achievements ของคุณ
	const achievementID = 1 
	const targetCoins = 15000

	// ถ้าเหรียญยังไม่ถึงเป้าหมาย ให้จบการทำงานทันที
	if currentCoins < targetCoins {
		return
	}

	ctx := context.Background()

	// คำสั่ง SQL ทำ Upsert ลงตาราง attain
	// ถ้ายังไม่มีข้อมูล: ให้ Insert สถานะ 'completed'
	// ถ้ามีข้อมูลอยู่แล้ว: ให้อัปเดตสถานะเป็น 'completed' (เฉพาะกรณีที่ยังไม่เคย completed มาก่อน)
	query := `
		INSERT INTO public.attain (user_id, achievement_id, status, completed_date, reward_claimed)
		VALUES ($1, $2, 'completed', NOW(), false)
		ON CONFLICT (user_id, achievement_id) 
		DO UPDATE SET 
			status = 'completed',
			completed_date = NOW()
		WHERE public.attain.status != 'completed';
	`

	// สั่ง Execute Query
	tag, err := configs.DB.Exec(ctx, query, userID, achievementID)
	if err != nil {
		fmt.Printf("❌ [CheckCoinAchievement] Failed to update achievement for user %s: %v\n", userID, err)
		return
	}

	// เช็คว่ามีการแทรกหรืออัปเดตข้อมูลจริงหรือไม่ (ป้องกันการเด้งซ้ำถ้าเคยได้ไปแล้ว)
	if tag.RowsAffected() > 0 {
		fmt.Printf("🎉 User %s just unlocked Achievement ID: %d (15,000 Coins)!\n", userID, achievementID)
		// อนาคตสามารถเพิ่มโค้ดส่ง Notification แจ้งเตือนผู้เล่นได้ตรงนี้
	}
}