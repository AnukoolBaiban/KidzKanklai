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
// Helper: ฟังก์ชันสุ่มรหัสเชิญ (เช่น ABC123)
// ------------------------------------------------------------------------
func generateInviteCode(length int) string {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}

// ------------------------------------------------------------------------
// API 1: สร้างชมรม (Create Club)
// ------------------------------------------------------------------------
type CreateClubInput struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"` // ส่งมาว่างๆ ได้
}

// POST /clubs/create
func CreateClub(c *gin.Context) {
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

	var input CreateClubInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "กรุณาระบุชื่อชมรม"})
		return
	}

	// 1. จัดการ Default ค่า Description
	if input.Description == "" {
		input.Description = "ไม่มีรายละเอียด"
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 2. เช็คว่าผู้เล่นมีชมรมอยู่แล้วหรือไม่ (1 คน อยู่ได้ 1 ชมรม)
	var currentClubID *int64
	checkUserQuery := `SELECT club_id FROM public.user_profiles WHERE id = $1 FOR UPDATE`
	err = tx.QueryRow(ctx, checkUserQuery, userID).Scan(&currentClubID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User not found"})
		return
	}
	if currentClubID != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณมีชมรมอยู่แล้ว ไม่สามารถสร้างใหม่ได้"})
		return
	}

	// 3. สุ่ม Invite Code และตรวจสอบว่าไม่ซ้ำ
	rand.Seed(time.Now().UnixNano())
	var inviteCode string
	var codeExists bool

	for {
		inviteCode = generateInviteCode(6) // สุ่มรหัส 6 หลัก
		err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM public.clubs WHERE invite_code = $1)`, inviteCode).Scan(&codeExists)
		if err == nil && !codeExists {
			break // ถ้ารหัสไม่ซ้ำ ให้ออกจาก Loop
		}
	}

	// 4. บันทึกข้อมูลชมรมลงฐานข้อมูล
	var newClubID int64
	insertClubQuery := `
		INSERT INTO public.clubs (name, description, invite_code, created_at) 
		VALUES ($1, $2, $3, NOW()) 
		RETURNING id
	`
	err = tx.QueryRow(ctx, insertClubQuery, input.Name, input.Description, inviteCode).Scan(&newClubID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถสร้างชมรมได้"})
		return
	}

	// 5. อัปเดตข้อมูลผู้เล่น ให้กลายเป็น 'owner' ของชมรมนี้
	updateUserQuery := `
		UPDATE public.user_profiles 
		SET club_id = $1, club_role = 'owner', club_join_date = NOW() 
		WHERE id = $2
	`
	_, err = tx.Exec(ctx, updateUserQuery, newClubID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถอัปเดตสถานะเจ้าของชมรมได้"})
		return
	}

	// ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"message":     "สร้างชมรมสำเร็จ",
		"club_id":     newClubID,
		"invite_code": inviteCode,
	})
}

// ------------------------------------------------------------------------
// API 2: เข้าร่วมชมรม (Join Club)
// ------------------------------------------------------------------------
type JoinClubInput struct {
	InviteCode string `json:"invite_code" binding:"required"`
}

// POST /clubs/join
func JoinClub(c *gin.Context) {
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

	var input JoinClubInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "กรุณาระบุรหัสเชิญ"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 1. เช็คว่าผู้เล่นมีชมรมอยู่แล้วหรือไม่
	var currentClubID *int64
	err = tx.QueryRow(ctx, `SELECT club_id FROM public.user_profiles WHERE id = $1 FOR UPDATE`, userID).Scan(&currentClubID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User not found"})
		return
	}
	if currentClubID != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณอยู่ในชมรมอื่นอยู่แล้ว กรุณาออกก่อนเข้าร่วมชมรมใหม่"})
		return
	}

	// 2. ค้นหาชมรมจากรหัสเชิญ
	var targetClubID int64
	var targetClubName string
	err = tx.QueryRow(ctx, `SELECT id, name FROM public.clubs WHERE invite_code = $1`, input.InviteCode).Scan(&targetClubID, &targetClubName)
	if err != nil {
		// ค้นหาไม่เจอ
		c.JSON(http.StatusBadRequest, gin.H{"error": "รหัสเชิญไม่ถูกต้อง หรือไม่มีชมรมนี้อยู่"})
		return
	}

	// 3. ตรวจสอบจำนวนสมาชิก (จำกัดไม่เกิน 50 คน)
	var memberCount int
	err = tx.QueryRow(ctx, `SELECT COUNT(*) FROM public.user_profiles WHERE club_id = $1`, targetClubID).Scan(&memberCount)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถตรวจสอบจำนวนสมาชิกได้"})
		return
	}
	if memberCount >= 50 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ชมรมนี้มีสมาชิกเต็มแล้ว (50/50)"})
		return
	}

	// 4. เพิ่มผู้เล่นเข้าชมรมในฐานะ 'member'
	updateUserQuery := `
		UPDATE public.user_profiles 
		SET club_id = $1, club_role = 'member', club_join_date = NOW() 
		WHERE id = $2
	`
	_, err = tx.Exec(ctx, updateUserQuery, targetClubID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถเข้าร่วมชมรมได้"})
		return
	}

	// ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("เข้าร่วมชมรม '%s' สำเร็จ!", targetClubName),
		"club_id": targetClubID,
	})
}