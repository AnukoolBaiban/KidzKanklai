package handlers

import (
	"backend/configs"
	"context"
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ------------------------------------------------------------------------
// API: สร้างข้อสอบประจำสัปดาห์ (Generate Weekly Exams)
// ------------------------------------------------------------------------
// POST /exams/generate-weekly
func GenerateWeeklyExams(c *gin.Context) {
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
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 0. Lock แถวของผู้เล่นคนนี้ไว้ เพื่อบังคับให้ API ที่ยิงมารัวๆ ต้องเข้าคิวทีละคน (แก้ปัญหาบั๊กสร้างข้อสอบเบิ้ล 9 ข้อ)
	var lockedID string
	lockQuery := `SELECT id FROM public.user_profiles WHERE id = $1 FOR UPDATE`
	err = tx.QueryRow(ctx, lockQuery, userID).Scan(&lockedID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to acquire user lock"})
		return
	}

	// 🌟 1. ลบข้อสอบเก่าของสัปดาห์ที่แล้วทิ้ง 
	// ลบออกจากตาราง exams โดยตรง (ข้อมูลใน conduct และ take จะโดนลบตามไปด้วยอัตโนมัติเพราะเราตั้ง ON DELETE CASCADE ไว้)
	cleanupQuery := `
		DELETE FROM public.exams 
		WHERE id IN (
			SELECT exam_id FROM public.conduct 
			WHERE user_id = $1 
			AND completed_date < date_trunc('week', current_date)
		)
	`
	_, err = tx.Exec(ctx, cleanupQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to cleanup old exams"})
		return
	}

	// 🌟 2. ตรวจสอบว่า "สัปดาห์นี้" มีการสร้างข้อสอบไปแล้วหรือยัง
	// ตอน insert ครั้งแรก completed_date คือเวลาที่สร้างข้อสอบ เราเลยใช้ค่านี้มาเช็คได้เลย
	var examsThisWeek int
	checkQuery := `
		SELECT COUNT(*) 
		FROM public.conduct 
		WHERE user_id = $1 
		AND completed_date >= date_trunc('week', current_date)
	`
	err = tx.QueryRow(ctx, checkQuery, userID).Scan(&examsThisWeek)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check existing exams"})
		return
	}

	// 🌟 3. ถ้ามีข้อสอบของสัปดาห์นี้อยู่แล้ว ให้ข้ามการสร้างไปเลย
	if examsThisWeek > 0 {
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"message": "Weekly exams already generated",
		})
		return
	}

	// 🌟 2. ดึงค่า Stat ปัจจุบันของผู้เล่น
	var pInt, pStr, pCre int
	charQuery := `SELECT intelligence, strength, creative FROM public.characters WHERE user_id = $1`
	err = tx.QueryRow(ctx, charQuery, userID).Scan(&pInt, &pStr, &pCre)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Character not found"})
		return
	}

	// 🌟 3. สุ่มประเภทของข้อสอบในสัปดาห์นี้ (สุ่มได้อะไร ใช้อันนั้นกับทั้ง 3 ตึก)
	rand.Seed(time.Now().UnixNano())
	types := []string{"intelligence", "strength", "creative"}
	examType := types[rand.Intn(len(types))]

	// 🌟 4. โครงสร้างของตึกสอบทั้ง 3 ระดับ
	difficulties := []struct {
		Name      string
		MaxBonus  int
		Coin      int
		Exp       int
	}{
		{Name: "ตึกสอบอังกฤษ", MaxBonus: 5, Coin: 1000, Exp: 50},       // ง่าย
		{Name: "ตึกสอบวิทยาศาสตร์", MaxBonus: 8, Coin: 1500, Exp: 100}, // ปานกลาง
		{Name: "ตึกสอบคณิตศาสตร์", MaxBonus: 11, Coin: 2000, Exp: 150}, // ยาก
	}

	detail := "ข้อสอบประจำสัปดาห์"
	staminaCost := 15

	// วนลูปสร้างข้อสอบทีละระดับ
	for _, diff := range difficulties {
		// 🌟 ตั้งค่าเริ่มต้นให้เท่ากับ Stat ปัจจุบันของผู้เล่นเป๊ะๆ
		reqInt := pInt
		reqStr := pStr
		reqCre := pCre

		// 🌟 แต้มกองกลางที่จะเอามาสุ่มแจก (5, 8 หรือ 11 แต้ม ตามระดับความยาก)
		pointsToDistribute := diff.MaxBonus

		// 🌟 สุ่มหยอดทีละ 1 แต้ม ลงใน 3 สเตตัส จนกว่าแต้มจะหมดกอง
		for i := 0; i < pointsToDistribute; i++ {
			choice := rand.Intn(3) // สุ่มได้เลข 0, 1 หรือ 2
			switch choice {
			case 0:
				reqInt++ // สุ่มโดน 0 ให้บวกความฉลาด 1 แต้ม
			case 1:
				reqStr++ // สุ่มโดน 1 ให้บวกความแข็งแรง 1 แต้ม
			case 2:
				reqCre++ // สุ่มโดน 2 ให้บวกความคิดสร้างสรรค์ 1 แต้ม
			}
		}

		// 4.1 Insert ลงตาราง exams (ไม่ต้องมี Status, Image, MapID)
		var examID int64
		insertExamQuery := `
			INSERT INTO public.exams (name, detail, type, intelligence, strength, creative, stamina)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			RETURNING id;
		`
		err = tx.QueryRow(ctx, insertExamQuery, diff.Name, detail, examType, reqInt, reqStr, reqCre, staminaCost).Scan(&examID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create exam"})
			return
		}

		// 4.2 ผูกข้อสอบเข้ากับผู้เล่นในตาราง conduct (ตั้งค่าเป็น pending เริ่มต้น)
		insertConductQuery := `
			INSERT INTO public.conduct (user_id, exam_id, status)
			VALUES ($1, $2, 'pending');
		`
		_, err = tx.Exec(ctx, insertConductQuery, userID, examID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to assign exam to user"})
			return
		}

		// 4.3 เพิ่มของรางวัลลงในตาราง take
		insertTakeQuery := `
			INSERT INTO public.take (exam_id, item_id, quantity)
			VALUES ($1, $2, $3);
		`
		// รางวัล Coin (สมมติ ItemID = 20)
		_, err = tx.Exec(ctx, insertTakeQuery, examID, 20, diff.Coin)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add Coin reward"})
			return
		}

		// รางวัล EXP (สมมติ ItemID = 22)
		_, err = tx.Exec(ctx, insertTakeQuery, examID, 22, diff.Exp)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add EXP reward"})
			return
		}
	}

	// ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Weekly exams generated successfully",
		"type":    examType,
	})
}

// ------------------------------------------------------------------------
// API: เริ่มทำข้อสอบ (Start Exam)
// ------------------------------------------------------------------------

type StartExamInput struct {
	ExamID int64 `json:"exam_id" binding:"required"`
}

// POST /exams/start
func StartExam(c *gin.Context) {
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

	var input StartExamInput
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

	// 🌟 1. ตรวจสอบและหักตั๋วสอบ (Exam Ticket Item ID = 18) 1 ใบ
	var ticketQuantity int
	checkTicketQuery := `SELECT quantity FROM public.collect WHERE user_id = $1 AND item_id = 18 FOR UPDATE`
	err = tx.QueryRow(ctx, checkTicketQuery, userID).Scan(&ticketQuantity)
	if err != nil || ticketQuantity <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Not enough EXAM_TICKET (Item ID: 18)"})
		return
	}

	// หักตั๋ว 1 ใบ
	updateTicketQuery := `UPDATE public.collect SET quantity = quantity - 1 WHERE user_id = $1 AND item_id = 18`
	_, err = tx.Exec(ctx, updateTicketQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to consume Exam Ticket"})
		return
	}

	// 🌟 2. ดึงข้อมูลข้อสอบ
	var examType string
	var reqInt, reqStr, reqCre, reqStamina int
	examQuery := `SELECT type, intelligence, strength, creative, stamina FROM public.exams WHERE id = $1`
	err = tx.QueryRow(ctx, examQuery, input.ExamID).Scan(&examType, &reqInt, &reqStr, &reqCre, &reqStamina)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Exam not found"})
		return
	}

	// 🌟 3. ดึงข้อมูล Stat ปัจจุบันของผู้เล่น
	var pInt, pStr, pCre, pStamina int
	charQuery := `SELECT intelligence, strength, creative, stamina FROM public.characters WHERE user_id = $1 FOR UPDATE`
	err = tx.QueryRow(ctx, charQuery, userID).Scan(&pInt, &pStr, &pCre, &pStamina)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Character not found"})
		return
	}

	// 🌟 4. ลอจิกคำนวณโอกาสสอบผ่าน (Pass Chance) แบบใหม่
	passChance := 95 // เริ่มต้นที่ 95%

	// 4.1 คำนวณ Energy (Stamina)
	if pStamina < reqStamina {
		passChance -= (reqStamina - pStamina) * 3 // ขาดไปแต้มละ -3%
	}

	// 4.2 คำนวณ Stat หลัก (Main Stat) และ Stat รอง (Sub Stats)
	calculateDeduction := func(playerStat, requiredStat int, isMainStat bool) int {
		if playerStat >= requiredStat {
			return 0 // ผ่านเกณฑ์ ไม่โดนหัก
		}
		
		missingPoints := requiredStat - playerStat
		if isMainStat {
			return missingPoints * 10 // Stat หลักขาด หักแต้มละ -10%
		}
		return missingPoints * 5 // Stat รองขาด หักแต้มละ -5%
	}

	passChance -= calculateDeduction(pInt, reqInt, examType == "intelligence")
	passChance -= calculateDeduction(pStr, reqStr, examType == "strength")
	passChance -= calculateDeduction(pCre, reqCre, examType == "creative")

	// ล็อกเปอร์เซ็นต์ให้อยู่ในช่วง 0 - 95%
	if passChance < 0 {
		passChance = 0
	}

	// 🌟 5. สุ่มทอยเต๋าเพื่อดูว่าสอบผ่านไหม (0 - 99)
	rand.Seed(time.Now().UnixNano())
	roll := rand.Intn(100) 
	isPassed := roll < passChance

	// 🌟 6. ถ้าสอบผ่าน ให้แจกของรางวัล
	var rewards []map[string]interface{}
	if isPassed {
		// อัปเดตสถานะข้อสอบในตาราง conduct เป็น completed
		updateConductQuery := `UPDATE public.conduct SET status = 'completed', completed_date = NOW() WHERE user_id = $1 AND exam_id = $2`
		_, err = tx.Exec(ctx, updateConductQuery, userID, input.ExamID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update conduct status"})
			return
		}

		// ดึงของรางวัลจากตาราง take
		rows, err := tx.Query(ctx, `
			SELECT t.item_id, t.quantity, i.name 
			FROM public.take t 
			JOIN public.items i ON t.item_id = i.id 
			WHERE t.exam_id = $1
		`, input.ExamID)
		
		if err == nil {
			// 🌟 6.1 [แก้ปัญหา conn busy] สร้าง Struct ชั่วคราวมาจดของรางวัลก่อน
			type tempReward struct {
				ItemID int64
				Qty    int
				Name   string
			}
			var pendingRewards []tempReward

			// ก๊อกที่ 1: อ่านข้อมูลแล้วจดไว้
			for rows.Next() {
				var itemID int64
				var qtyPtr *int
				var namePtr *string

				if err := rows.Scan(&itemID, &qtyPtr, &namePtr); err == nil {
					qty := 0
					if qtyPtr != nil {
						qty = *qtyPtr
					}
					name := "Unknown"
					if namePtr != nil {
						name = *namePtr
					}
					pendingRewards = append(pendingRewards, tempReward{
						ItemID: itemID, Qty: qty, Name: name,
					})
				} else {
					fmt.Println("❌ Scan Error:", err)
				}
			}
			rows.Close() // 🌟 ปิดสาย Connection ให้ว่างทันที!

			// 🌟 6.2 ก๊อกที่ 2: นำข้อมูลที่จดไว้มาแจกจ่ายลง Database (รับรองไม่ติด conn busy)
			expGained := 0
			for _, item := range pendingRewards {
				
				// ตรวจสอบว่าเป็น EXP หรือไม่
				if item.ItemID == 22 || item.Name == "EXP" {
					expGained += item.Qty
				} else {
					// ไอเทมอื่นๆ (เช่น Coin) ยัดเข้า Inventory
					insertOrUpdateCollect := `
						INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
						VALUES ($1, $2, $3, NOW())
						ON CONFLICT (user_id, item_id) 
						DO UPDATE SET 
							quantity = public.collect.quantity + EXCLUDED.quantity,
							acquired_date = NOW();
					`
					_, err := tx.Exec(ctx, insertOrUpdateCollect, userID, item.ItemID, item.Qty)
					if err != nil {
						fmt.Printf("❌ Failed to add Coin/Item %d: %v\n", item.ItemID, err)
					}
				}

				rewards = append(rewards, map[string]interface{}{
					"item_id": item.ItemID,
					"name":    item.Name,
					"amount":  item.Qty,
				})
			}

			// อัปเดต EXP เข้า Character
			if expGained > 0 {
				updateExpQuery := `UPDATE public.characters SET experience = experience + $1 WHERE user_id = $2`
				_, err := tx.Exec(ctx, updateExpQuery, expGained, userID)
				if err != nil {
					fmt.Println("❌ Failed to update EXP:", err)
				}
			}
		}
	} else {
		// ถ้าสอบตก ให้ค้างสถานะ pending ไว้เหมือนเดิมเผื่อกดสอบซ้ำ
	}

	// ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"is_passed":   isPassed,
		"pass_chance": passChance,
		"roll_result": roll,
		"rewards":     rewards,
	})
}