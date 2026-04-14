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
// API: ทำกิจกรรมในสถานที่ต่างๆ (Location Action)
// ------------------------------------------------------------------------

type LocationActionInput struct {
	Location string `json:"location" binding:"required"` // "library", "gym", "amusement_park", "park"
}

// POST /locations/action
func PerformLocationAction(c *gin.Context) {
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

	var input LocationActionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input: location is required"})
		return
	}

	// ตรวจสอบว่าสถานที่ที่ส่งมาถูกต้องหรือไม่
	validLocations := map[string]bool{"library": true, "gym": true, "amusement_park": true, "park": true}
	if !validLocations[input.Location] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid location"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 1. ตรวจสอบและหักตั๋ว Energy Ticket (Item ID = 21)
	var ticketQuantity int
	checkTicketQuery := `SELECT quantity FROM public.collect WHERE user_id = $1 AND item_id = 21 FOR UPDATE`
	err = tx.QueryRow(ctx, checkTicketQuery, userID).Scan(&ticketQuantity)
	if err != nil || ticketQuantity <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Not enough ENERGY_TICKET (Item ID: 21)"})
		return
	}

	// หักตั๋ว 1 ใบ
	updateTicketQuery := `UPDATE public.collect SET quantity = quantity - 1 WHERE user_id = $1 AND item_id = 21`
	_, err = tx.Exec(ctx, updateTicketQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to consume Energy Ticket"})
		return
	}

	// 🌟 2. ดึงข้อมูลตัวละคร (สเตตัสปัจจุบัน)
	var stamina, intelligence, strength, creative int
	checkCharQuery := `
		SELECT stamina, intelligence, strength, creative 
		FROM public.characters 
		WHERE user_id = $1 FOR UPDATE
	`
	err = tx.QueryRow(ctx, checkCharQuery, userID).Scan(&stamina, &intelligence, &strength, &creative)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Character not found"})
		return
	}

	// ตั้งค่าสุ่มตัวเลข
	rand.Seed(time.Now().UnixNano())

	isSuccess := true
	message := ""
	staminaChange := 0
	statGained := ""

	// 🌟 3. ลอจิกคำนวณตามสถานที่
	if input.Location == "park" {
		// --- สวนสาธารณะ (ฟื้นฟูพลังงาน) ---
		staminaChange = rand.Intn(21) + 70 // สุ่ม 70 ถึง 90
		stamina += staminaChange
		if stamina > 100 {
			stamina = 100 // ล็อกไม่ให้เกิน 100
		}
		message = fmt.Sprintf("ฟื้นฟูพลังงานสำเร็จ! (+%d Stamina)", staminaChange)
		statGained = "stamina"

	} else {
		// --- สถานที่ฝึกฝน (หอสมุด, โรงยิม, สวนสนุก) ---
		staminaCost := rand.Intn(11) + 10 // สุ่มใช้พลังงาน 10 ถึง 20
		staminaChange = -staminaCost

		if stamina >= staminaCost {
			// พลังงานพอ -> ฝึกสำเร็จ
			stamina -= staminaCost
			
			switch input.Location {
			case "library":
				intelligence += 1
				statGained = "intelligence"
				message = fmt.Sprintf("ฝึกฝนสำเร็จ! Intelligence +1 (ใช้ %d Stamina)", staminaCost)
			case "gym":
				strength += 1
				statGained = "strength"
				message = fmt.Sprintf("ออกกำลังกายสำเร็จ! Strength +1 (ใช้ %d Stamina)", staminaCost)
			case "amusement_park":
				creative += 1
				statGained = "creative"
				message = fmt.Sprintf("หาแรงบันดาลใจสำเร็จ! Creative +1 (ใช้ %d Stamina)", staminaCost)
			}
		} else {
			// พลังงานไม่พอ -> ล้มเหลว (เสียตั๋ว, stamina เหลือ 0, ไม่ได้ stat)
			staminaChange = -stamina // เสียเท่าที่มีอยู่
			stamina = 0
			isSuccess = false
			message = "เหนื่อยล้าเกินไป! ฝึกฝนล้มเหลว พลังงานลดลงเหลือ 0"
		}
	}

	// 🌟 4. อัปเดตข้อมูลกลับลงฐานข้อมูล
	updateCharQuery := `
		UPDATE public.characters 
		SET stamina = $1, intelligence = $2, strength = $3, creative = $4 
		WHERE user_id = $5
	`
	_, err = tx.Exec(ctx, updateCharQuery, stamina, intelligence, strength, creative, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update character stats"})
		return
	}

	// ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	// 🌟 5. ส่ง Response กลับไปให้ Flutter
	c.JSON(http.StatusOK, gin.H{
		"success":         isSuccess,        // บอกว่าฝึกสำเร็จหรือล้มเหลว (ถ้าฟื้นฟูจะได้ true เสมอ)
		"message":         message,          // ข้อความแจ้งเตือนพร้อมโชว์ในแอป
		"stamina_change":  staminaChange,    // ค่าพลังงานที่เปลี่ยน (ติดลบคือเสีย, ค่าบวกคือได้เพิ่ม)
		"stat_gained":     statGained,       // ชื่อ stat ที่ได้ (เพื่อนำไปโชว์ไอคอน)
		"current_stamina": stamina,          // ค่าพลังงานปัจจุบันที่เหลืออยู่
	})
}

