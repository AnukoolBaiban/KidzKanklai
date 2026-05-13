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
	var isJoinable bool // 🌟 1. เพิ่มตัวแปรมารับค่า is_joinable

	// 🌟 2. เพิ่ม is_joinable ลงในคำสั่ง SELECT
	err = tx.QueryRow(ctx, `SELECT id, name, is_joinable FROM public.clubs WHERE invite_code = $1`, input.InviteCode).Scan(&targetClubID, &targetClubName, &isJoinable)
	if err != nil {
		// ค้นหาไม่เจอ
		c.JSON(http.StatusBadRequest, gin.H{"error": "รหัสเชิญไม่ถูกต้อง หรือไม่มีชมรมนี้อยู่"})
		return
	}

	// 🌟 3. เช็คว่าชมรมเปิดรับคนอยู่หรือไม่
	if !isJoinable {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ชมรมนี้ปิดรับสมาชิกชั่วคราว ไม่สามารถเข้าร่วมได้"})
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

// ------------------------------------------------------------------------
// API: เปิด/ปิด การรับสมาชิกชมรม (Toggle Joinable Status)
// ------------------------------------------------------------------------

type ToggleJoinInput struct {
	IsJoinable bool `json:"is_joinable"` // รับค่า true (เปิดรับ) หรือ false (ปิดรับ)
}

// POST /clubs/toggle_join
func ToggleJoinStatus(c *gin.Context) {
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

	var input ToggleJoinInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ข้อมูลไม่ถูกต้อง กรุณาส่งค่า is_joinable (boolean)"})
		return
	}

	ctx := context.Background()

	// 1. ตรวจสอบว่าผู้ใช้เป็นเจ้าของชมรมหรือไม่
	var clubID int64
	var clubRole string
	err = configs.DB.QueryRow(ctx, `SELECT COALESCE(club_id, 0), COALESCE(club_role, '') FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณยังไม่มีชมรม"})
		return
	}
	
	if clubRole != "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เฉพาะหัวหน้าชมรมเท่านั้นที่สามารถเปลี่ยนสถานะการรับสมาชิกได้"})
		return
	}

	// 2. อัปเดตสถานะ is_joinable ของชมรม
	updateQuery := `UPDATE public.clubs SET is_joinable = $1 WHERE id = $2`
	_, err = configs.DB.Exec(ctx, updateQuery, input.IsJoinable, clubID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถเปลี่ยนสถานะชมรมได้ โปรดลองอีกครั้ง"})
		return
	}

	// 3. เตรียมข้อความตอบกลับ
	statusMsg := "ปิด"
	if input.IsJoinable {
		statusMsg = "เปิด"
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"message":     fmt.Sprintf("%sรับสมาชิกเรียบร้อยแล้ว", statusMsg),
		"is_joinable": input.IsJoinable,
	})
}

// ------------------------------------------------------------------------
// API 3: ลาออกจากชมรม (Leave Club)
// ------------------------------------------------------------------------
// POST /clubs/leave
func LeaveClub(c *gin.Context) {
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

	// ตรวจสอบว่าผู้เล่นเป็นสมาชิกชมรมจริงหรือไม่ และไม่ใช่หัวหน้า
	var clubRole *string
	err = tx.QueryRow(ctx, `SELECT club_role FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubRole)
	
	if err != nil || clubRole == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณไม่ได้อยู่ในชมรมใดเลย"})
		return
	}

	if *clubRole == "owner" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "เจ้าของชมรมไม่สามารถลาออกได้ ต้องยุบชมรมเท่านั้น"})
		return
	}

	// อัปเดตข้อมูล ลบ club_id, club_role, และ club_join_date ทิ้ง
	updateUserQuery := `
		UPDATE public.user_profiles 
		SET club_id = NULL, club_role = NULL, club_join_date = NULL 
		WHERE id = $1
	`
	_, err = tx.Exec(ctx, updateUserQuery, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถลาออกจากชมรมได้"})
		return
	}

	// ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "ลาออกจากชมรมสำเร็จ",
	})
}

// ------------------------------------------------------------------------
// API 4: ไล่สมาชิกออกจากชมรม (Kick Member) - เฉพาะหัวหน้าชมรม
// ------------------------------------------------------------------------
type KickMemberInput struct {
	TargetUserID string `json:"target_user_id" binding:"required"`
}

// POST /clubs/kick
func KickMember(c *gin.Context) {
	// 1. ดึง ID ของคนที่กดส่งคำสั่ง (คนเตะ)
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	ownerIDStr := fmt.Sprintf("%v", userIdVal)
	ownerID, err := uuid.Parse(ownerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// 2. รับค่า ID ของคนที่โดนเตะจาก Body
	var input KickMemberInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "กรุณาระบุ ID ของสมาชิกที่ต้องการไล่ออก"})
		return
	}

	targetUserID, err := uuid.Parse(input.TargetUserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid target user ID"})
		return
	}

	// ป้องกันการเตะตัวเอง
	if ownerID == targetUserID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณไม่สามารถไล่ตัวเองออกจากชมรมได้"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 3. ตรวจสอบสิทธิ์คนเตะ (ต้องเป็นเจ้าของชมรม)
	var ownerClubID *int64
	var ownerRole *string
	err = tx.QueryRow(ctx, `SELECT club_id, club_role FROM public.user_profiles WHERE id = $1`, ownerID).Scan(&ownerClubID, &ownerRole)
	if err != nil || ownerClubID == nil || ownerRole == nil || *ownerRole != "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เฉพาะหัวหน้าชมรมเท่านั้นที่สามารถไล่สมาชิกออกได้"})
		return
	}

	// 4. ตรวจสอบคนโดนเตะ (ต้องอยู่ในชมรมเดียวกันกับ Owner)
	var targetClubID *int64
	var targetRole *string
	err = tx.QueryRow(ctx, `SELECT club_id, club_role FROM public.user_profiles WHERE id = $1 FOR UPDATE`, targetUserID).Scan(&targetClubID, &targetRole)
	if err != nil || targetClubID == nil || *targetClubID != *ownerClubID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ไม่พบผู้เล่นนี้ในชมรมของคุณ"})
		return
	}

	// (ป้องกันเหนียวไว้อีกชั้น: Target ไม่ควรเป็น owner)
	if targetRole != nil && *targetRole == "owner" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ไม่สามารถไล่หัวหน้าชมรมได้"})
		return
	}

	// 5. เตะออกจากชมรม (เคลียร์ค่า club_id, club_role, และ club_join_date เป็น NULL)
	updateUserQuery := `
		UPDATE public.user_profiles 
		SET club_id = NULL, club_role = NULL, club_join_date = NULL 
		WHERE id = $1
	`
	_, err = tx.Exec(ctx, updateUserQuery, targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถไล่สมาชิกออกได้"})
		return
	}

	// 🌟 6. สร้างการแจ้งเตือนบอกผู้เล่นที่โดนเตะ
	var clubName string
	err = tx.QueryRow(ctx, `SELECT name FROM public.clubs WHERE id = $1`, *ownerClubID).Scan(&clubName)
	if err == nil {
		CreateClubKickNotification(ctx, targetUserID, clubName)
	}

	// ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "ไล่สมาชิกออกจากชมรมเรียบร้อยแล้ว",
	})
}

// ------------------------------------------------------------------------
// API 5: ยุบชมรม (Delete/Disband Club) - เฉพาะหัวหน้าชมรม
// ------------------------------------------------------------------------

// POST /clubs/delete
func DeleteClub(c *gin.Context) {
	// 1. ดึง ID ของผู้ใช้งาน
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

	// 2. ตรวจสอบสิทธิ์ (ต้องเป็นเจ้าของชมรมเท่านั้น)
	var clubID *int64
	var clubRole *string
	err = tx.QueryRow(ctx, `SELECT club_id, club_role FROM public.user_profiles WHERE id = $1 FOR UPDATE`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == nil || clubRole == nil || *clubRole != "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เฉพาะหัวหน้าชมรมเท่านั้นที่สามารถยุบชมรมได้"})
		return
	}

	// 3. ปลดสมาชิกทุกคนออกจากชมรมนี้ (เซ็ต club_id, club_role, club_join_date เป็น NULL)
	// หมายเหตุ: รวมตัวหัวหน้าเองด้วย จึงไม่ต้อง Where ยกเว้นใคร
	clearMembersQuery := `
		UPDATE public.user_profiles 
		SET club_id = NULL, club_role = NULL, club_join_date = NULL 
		WHERE club_id = $1
	`
	_, err = tx.Exec(ctx, clearMembersQuery, *clubID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถปลดสมาชิกออกจากชมรมได้"})
		return
	}

	// 4. ลบชมรมออกจากตาราง clubs
	// 💡 หมายเหตุ: หากตาราง quests มีการเชื่อม FK club_id ไว้ ต้องมั่นใจว่าตั้งค่าเป็น ON DELETE CASCADE
	// หรือไม่ก็ต้องเขียนคำสั่งลบ quests ของชมรมนี้ทิ้งก่อนลบคลับครับ
	deleteClubQuery := `DELETE FROM public.clubs WHERE id = $1`
	_, err = tx.Exec(ctx, deleteClubQuery, *clubID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ลบข้อมูลชมรมล้มเหลว กรุณาตรวจสอบว่ามีข้อมูลค้างในระบบหรือไม่"})
		return
	}

	// 5. ยืนยัน Transaction
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "ยุบชมรมเรียบร้อยแล้ว",
	})
}

// ------------------------------------------------------------------------
// API 6: อัปเดตข้อมูลชมรม (Update Club) - เฉพาะหัวหน้าชมรม
// ------------------------------------------------------------------------
type UpdateClubInput struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
}

// POST /clubs/update
func UpdateClub(c *gin.Context) {
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

	var input UpdateClubInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ข้อมูลไม่ถูกต้อง"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// ตรวจสอบสิทธิ์ (ต้องเป็นเจ้าของชมรมเท่านั้น)
	var clubID *int64
	var clubRole *string
	err = tx.QueryRow(ctx, `SELECT club_id, club_role FROM public.user_profiles WHERE id = $1 FOR UPDATE`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == nil || clubRole == nil || *clubRole != "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เฉพาะหัวหน้าชมรมเท่านั้นที่สามารถแก้ไขข้อมูลชมรมได้"})
		return
	}

	if input.Name != nil && input.Description != nil {
		_, err = tx.Exec(ctx, `UPDATE public.clubs SET name = $1, description = $2 WHERE id = $3`, *input.Name, *input.Description, *clubID)
	} else if input.Name != nil {
		_, err = tx.Exec(ctx, `UPDATE public.clubs SET name = $1 WHERE id = $2`, *input.Name, *clubID)
	} else if input.Description != nil {
		_, err = tx.Exec(ctx, `UPDATE public.clubs SET description = $1 WHERE id = $2`, *input.Description, *clubID)
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ไม่สามารถอัปเดตข้อมูลชมรมได้"})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "อัปเดตข้อมูลชมรมเรียบร้อยแล้ว",
	})
}
