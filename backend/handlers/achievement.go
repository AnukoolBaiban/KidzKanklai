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

// ------------------------------------------------------------------------
// CheckLevelAchievement: เช็คเมื่อตัวละครมีการเปลี่ยนเลเวล
// - ถึง Lv 5 (Achievement ID = 2)
// - ถึง Lv 15 (Achievement ID = 3)
// - ถึง Lv 30 (Achievement ID = 4)
// ------------------------------------------------------------------------
func CheckLevelAchievement(ctx context.Context, userID uuid.UUID) {
	// คิวรี่หา Level ปัจจุบัน
	var currentLevel int
	query := `SELECT level FROM public.characters WHERE user_id = $1`
	err := configs.DB.QueryRow(ctx, query, userID).Scan(&currentLevel)
	if err != nil {
		fmt.Printf("❌ [CheckLevelAchievement] Failed to get level for user %s: %v\n", userID, err)
		return
	}

	// สร้าง Map เก็บเงื่อนไข (AchievementID -> Level เป้าหมาย)
	levelTargets := map[int]int{
		2: 5,  // ID 2 -> เลเวล 5
		3: 15, // ID 3 -> เลเวล 15
		4: 30, // ID 4 -> เลเวล 30
	}

	// ลูปตรวจทีละเงื่อนไข
	for achID, targetLevel := range levelTargets {
		if currentLevel >= targetLevel {
			// บันทึก/อัปเดตลงตาราง attain
			attainQuery := `
				INSERT INTO public.attain (user_id, achievement_id, status, completed_date, reward_claimed)
				VALUES ($1, $2, 'completed', NOW(), false)
				ON CONFLICT (user_id, achievement_id) 
				DO UPDATE SET 
					status = 'completed',
					completed_date = NOW()
				WHERE public.attain.status != 'completed';
			`
			tag, err := configs.DB.Exec(ctx, attainQuery, userID, achID)
			if err != nil {
				fmt.Printf("❌ [CheckLevelAchievement] Failed to update achievement %d for user %s: %v\n", achID, userID, err)
				continue
			}

			// ถ้าปลดล็อกใหม่ ให้ส่งแจ้งเตือน
			if tag.RowsAffected() > 0 {
				fmt.Printf("🎉 User %s just unlocked Achievement ID: %d (Level %d)!\n", userID, achID, targetLevel)
				notifyAchievementUnlocked(userID, achID)
			}
		}
	}
}

// ------------------------------------------------------------------------
// CheckStatAchievement: เช็คเมื่อตัวละครมีการเปลี่ยนค่า Stats
// - ความฉลาด (intelligence) ถึง 50 (Achievement ID = 5)
// - ความแข็งแรง (strength) ถึง 50 (Achievement ID = 6)
// - ความคิดสร้างสรรค์ (creative) ถึง 50 (Achievement ID = 7)
// - ทุก Stats (int, str, cre) ถึง 100 (Achievement ID = 8)
// ------------------------------------------------------------------------
func CheckStatAchievement(ctx context.Context, userID uuid.UUID) {
	// คิวรี่หา Stats ปัจจุบัน
	var intl, str, cre int
	query := `SELECT intelligence, strength, creative FROM public.characters WHERE user_id = $1`
	err := configs.DB.QueryRow(ctx, query, userID).Scan(&intl, &str, &cre)
	if err != nil {
		fmt.Printf("❌ [CheckStatAchievement] Failed to get stats for user %s: %v\n", userID, err)
		return
	}

	// สร้าง Map เก็บเงื่อนไขที่เพิ่งทำสำเร็จ
	unlockedAchIDs := []int{}

	// เงื่อนไขเดี่ยว
	if intl >= 50 { unlockedAchIDs = append(unlockedAchIDs, 5) }
	if str >= 50 { unlockedAchIDs = append(unlockedAchIDs, 6) }
	if cre >= 50 { unlockedAchIDs = append(unlockedAchIDs, 7) }
	
	// เงื่อนไขรวม (ทุก Stat ถึง 100)
	if intl >= 100 && str >= 100 && cre >= 100 { 
		unlockedAchIDs = append(unlockedAchIDs, 8) 
	}

	// ลูปบันทึก Achievement ที่ผ่านเงื่อนไข
	for _, achID := range unlockedAchIDs {
		attainQuery := `
			INSERT INTO public.attain (user_id, achievement_id, status, completed_date, reward_claimed)
			VALUES ($1, $2, 'completed', NOW(), false)
			ON CONFLICT (user_id, achievement_id) 
			DO UPDATE SET 
				status = 'completed',
				completed_date = NOW()
			WHERE public.attain.status != 'completed';
		`
		tag, err := configs.DB.Exec(ctx, attainQuery, userID, achID)
		if err != nil {
			fmt.Printf("❌ [CheckStatAchievement] Failed to update achievement %d for user %s: %v\n", achID, userID, err)
			continue
		}

		// ถ้าปลดล็อกใหม่ ให้ส่งแจ้งเตือน
		if tag.RowsAffected() > 0 {
			fmt.Printf("🎉 User %s just unlocked Achievement ID: %d (Stats)!\n", userID, achID)
			notifyAchievementUnlocked(userID, achID)
		}
	}
}

// ------------------------------------------------------------------------
// Helper: ดึงข้อมูลชื่อและรูปเพื่อยิง Notification (ลดความซ้ำซ้อนโค้ด)
// ------------------------------------------------------------------------
func notifyAchievementUnlocked(userID uuid.UUID, achievementID int) {
	ctx := context.Background()

	var achName string
	var achImagePtr *string
	achQuery := `SELECT name, image FROM public.achievements WHERE id = $1`
	achErr := configs.DB.QueryRow(ctx, achQuery, achievementID).Scan(&achName, &achImagePtr)

	achImage := "assets/images/icon/iconAchievement.png" // รูปสำรอง
	if achErr == nil && achImagePtr != nil && *achImagePtr != "" {
		achImage = *achImagePtr
	}

	// โยนเข้า Goroutine สร้าง Notification
	go func(u uuid.UUID, name, image string) {
		CreateAchievementNotification(context.Background(), u, name, image)
	}(userID, achName, achImage)
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