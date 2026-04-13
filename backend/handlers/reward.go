package handlers

import (
	"backend/configs"
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// 🌟 1. เพิ่มฟิลด์ Image ใน Struct สำหรับ Response
type RewardResponse struct {
	ItemID int64  `json:"item_id"`
	Name   string `json:"name"`
	Image  string `json:"image"` // <--- เพิ่มตรงนี้
	Added  int    `json:"added"`
	Total  int    `json:"total"`
}

// POST /rewards/login-bonus
func ClaimLoginTickets(c *gin.Context) {
	userId, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	loc, _ := time.LoadLocation("Asia/Bangkok")
	now := time.Now().In(loc)
	ctx := context.Background()

	// --- ส่วนที่ 1: ดึงข้อมูลตั๋วที่ผู้เล่นมีอยู่ปัจจุบัน (จากตาราง collect) ---
	query := `
		SELECT item_id, quantity, acquired_date 
		FROM public.collect 
		WHERE user_id = $1 AND item_id IN (17, 18, 19)
	`
	rows, err := configs.DB.Query(ctx, query, userId)
	if err != nil {
		fmt.Println("❌ ClaimLoginTickets Query Error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory"})
		return
	}

	type invData struct {
		Quantity     int
		AcquiredDate time.Time
	}
	inventoryMap := make(map[int64]invData)

	for rows.Next() {
		var itemID int64
		var qty int
		var acquired time.Time
		if err := rows.Scan(&itemID, &qty, &acquired); err == nil {
			inventoryMap[itemID] = invData{Quantity: qty, AcquiredDate: acquired.In(loc)}
		}
	}
	rows.Close()

	// 🌟 --- ส่วนที่ 2: ดึงข้อมูลชื่อและรูปภาพ จากตาราง items ---
	itemQuery := `SELECT id, name, image FROM public.items WHERE id IN (17, 18, 19)`
	itemRows, err := configs.DB.Query(ctx, itemQuery)
	if err != nil {
		fmt.Println("❌ Fetch Items Data Error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch items data"})
		return
	}

	type itemInfo struct {
		Name  string
		Image string
	}
	itemsMap := make(map[int64]itemInfo)

	for itemRows.Next() {
		var id int64
		var name string
		var image *string // ใช้ Pointer เผื่อตารางในฐานข้อมูลเป็น NULL

		if err := itemRows.Scan(&id, &name, &image); err == nil {
			imgStr := ""
			if image != nil {
				imgStr = *image // ดึงค่า Path รูปออกมา
			}
			itemsMap[id] = itemInfo{Name: name, Image: imgStr}
		}
	}
	itemRows.Close()
	// -------------------------------------------------------------

	var rewards []RewardResponse

	// เริ่ม Transaction สำหรับอัปเดต DB
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 3. ปรับฟังก์ชันช่วยทำ Upsert
	upsertTicket := func(itemID int64, maxCap int, addedAmt int, isDaily bool) {
		inv, exists := inventoryMap[itemID]

		shouldGive := false
		if !exists {
			shouldGive = true
		} else {
			if isDaily {
				shouldGive = isNewDay(inv.AcquiredDate, now)
			} else {
				shouldGive = isNewWeek(inv.AcquiredDate, now)
			}
		}

		if shouldGive {
			currentQty := 0
			if exists {
				currentQty = inv.Quantity
			}

			newTotal := currentQty + addedAmt
			if newTotal > maxCap {
				newTotal = maxCap
				addedAmt = newTotal - currentQty // ถ้าเต็มแล้ว addedAmt จะกลายเป็น 0
			}

			// 🌟 1. ลบ if addedAmt > 0 ออก เพื่อบังคับอัปเดต Database เสมอ! 
            // จะได้รีเซ็ตเวลา acquired_date เป็นของสัปดาห์นี้ ปิดช่องโหว่การได้ตั๋วซ้ำซ้อน
			upsertQuery := `
				INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
				VALUES ($1, $2, $3, $4)
				ON CONFLICT (user_id, item_id) 
				DO UPDATE SET 
					quantity = EXCLUDED.quantity,
					acquired_date = EXCLUDED.acquired_date;
			`
			_, err := tx.Exec(ctx, upsertQuery, userId, itemID, newTotal, now)
			
            if err == nil {
				
				// 🌟 2. นำ if addedAmt > 0 มาครอบตอนส่ง Response กลับไปให้แอปแทน
                // ถ้าตั๋วเต็มแล้ว (ได้ 0 ใบ) ก็ไม่ต้องส่งไปโชว์ใน Popup ให้รกตา
				if addedAmt > 0 {
					itemName := "Unknown Item"
					itemImage := "assets/images/item/default_item.png"
					if info, ok := itemsMap[itemID]; ok {
						itemName = info.Name
						if info.Image != "" {
							itemImage = info.Image
						}
					}

					rewards = append(rewards, RewardResponse{
						ItemID: itemID,
						Name:   itemName,
						Image:  itemImage,
						Added:  addedAmt,
						Total:  newTotal,
					})
				}

			} else {
				fmt.Printf("❌ Upsert Error for item %d: %v\n", itemID, err)
			}
		}
	}

	// 🌟 ตอนเรียกใช้ ไม่ต้องพิมพ์ชื่อตั๋วเองแล้ว ใส่แค่ (ID, MaxCap, จำนวนที่แจก, เป็นรายวันใช่ไหม?)
	upsertTicket(17, 7, 1, true)  // QUEST_TICKET
	upsertTicket(18, 3, 3, false) // EXAM_TICKET
	upsertTicket(19, 3, 3, false) // CLUB_TICKET

	// Commit
	if err := tx.Commit(ctx); err != nil {
		fmt.Println("❌ Commit Error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save rewards"})
		return
	}

	// ส่ง Response กลับไปให้ Flutter
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"rewards": rewards,
	})
}

// 🌟 Struct สำหรับรับค่าจาก Flutter ตอนกดปุ่มรับรางวัล
type ClaimAchievementInput struct {
	AchievementID int64 `json:"achievement_id" binding:"required"`
}

// POST /rewards/claim-achievement (กดรับรางวัลจากหน้า Achievement)
func ClaimAchievementReward(c *gin.Context) {
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

	var input ClaimAchievementInput
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

	// 1. เช็คสถานะความสำเร็จ
	var statusPtr *string
	var rewardClaimedPtr *bool

	checkQuery := `
		SELECT status, reward_claimed 
		FROM public.attain 
		WHERE user_id = $1 AND achievement_id = $2 
		FOR UPDATE
	`
	err = tx.QueryRow(ctx, checkQuery, userID, input.AchievementID).Scan(&statusPtr, &rewardClaimedPtr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Achievement not found or not completed yet"})
		return
	}

	if statusPtr == nil || *statusPtr != "completed" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Achievement is not completed yet"})
		return
	}

	if rewardClaimedPtr != nil && *rewardClaimedPtr == true {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Reward already claimed"})
		return
	}

	// 2. ดึงข้อมูลของรางวัล
	rewardQuery := `
		SELECT g.item_id, g.quantity, i.name, i.image 
		FROM public.give g
		JOIN public.items i ON g.item_id = i.id
		WHERE g.achievement_id = $1
	`
	rows, err := tx.Query(ctx, rewardQuery, input.AchievementID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch rewards"})
		return
	}

	// 🌟 [แก้ปัญหา conn busy] สร้าง Struct ชั่วคราวมาเก็บข้อมูลที่โหลดมาก่อน
	type tempReward struct {
		ItemID int64
		Qty    int
		Name   string
		Image  string
	}
	var pendingRewards []tempReward

	// ก๊อกที่ 1: วนลูปเพื่อ "อ่านและจด" ข้อมูลลง Memory
	for rows.Next() {
		var itemID int64
		var qtyPtr *int
		var namePtr *string
		var imagePtr *string

		if err := rows.Scan(&itemID, &qtyPtr, &namePtr, &imagePtr); err == nil {
			qty := 0
			if qtyPtr != nil {
				qty = *qtyPtr
			}
			name := "Unknown Item"
			if namePtr != nil {
				name = *namePtr
			}
			imageStr := "assets/images/item/default_item.png"
			if imagePtr != nil && *imagePtr != "" {
				imageStr = *imagePtr
			}
			// จดใส่ Array ชั่วคราวไว้ก่อน
			pendingRewards = append(pendingRewards, tempReward{
				ItemID: itemID, Qty: qty, Name: name, Image: imageStr,
			})
		}
	}
	// 🌟 ปิดสาย Connection ของลูป Select ทันที เพื่อให้สายกลับมาว่าง!
	rows.Close()

	// -------------------------------------------------------------------

	// ก๊อกที่ 2: วนลูปเพื่อ "แจกของ" ลง Database
	rewards := make([]RewardResponse, 0)

	for _, item := range pendingRewards {
		upsertQuery := `
			INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
			VALUES ($1, $2, $3, NOW())
			ON CONFLICT (user_id, item_id)
			DO UPDATE SET 
				quantity = public.collect.quantity + EXCLUDED.quantity,
				acquired_date = NOW()
			RETURNING quantity;
		`
		var totalQty int
		// สายว่างแล้ว สามารถใช้ tx.QueryRow ได้โดยไม่ติด Error conn busy
		err = tx.QueryRow(ctx, upsertQuery, userID, item.ItemID, item.Qty).Scan(&totalQty)
		if err != nil {
			fmt.Printf("❌ Failed to give item %d: %v\n", item.ItemID, err)
			continue
		}

		rewards = append(rewards, RewardResponse{
			ItemID: item.ItemID,
			Name:   item.Name,
			Image:  item.Image,
			Added:  item.Qty,
			Total:  totalQty,
		})
	}

	// 4. อัปเดตสถานะว่ารับรางวัลแล้ว
	updateAttainQuery := `
		UPDATE public.attain 
		SET reward_claimed = true 
		WHERE user_id = $1 AND achievement_id = $2
	`
	_, err = tx.Exec(ctx, updateAttainQuery, userID, input.AchievementID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update claim status"})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Reward claimed successfully",
		"rewards": rewards,
	})
}

// เช็ควันใหม่
func isNewDay(lastDate time.Time, now time.Time) bool {
	return lastDate.YearDay() != now.YearDay() || lastDate.Year() != now.Year()
}

// เช็คสัปดาห์ใหม่
func isNewWeek(lastDate time.Time, now time.Time) bool {
	lastYear, lastWeek := lastDate.ISOWeek()
	nowYear, nowWeek := now.ISOWeek()
	return lastYear != nowYear || lastWeek != nowWeek
}
