package handlers

import (
	"context"
	"net/http"
	"backend/configs" // ตรวจสอบ path ให้ตรงกับโฟลเดอร์ของคุณ

	"github.com/gin-gonic/gin"
)

// Struct สำหรับรับค่า JSON เฉพาะชื่อ
type UpdateNameInput struct {
	Name string `json:"name" binding:"required"`
}

// Struct สำหรับรับค่า JSON เฉพาะ Bio (Detail)
type UpdateBioInput struct {
	Bio string `json:"bio" binding:"required"`
}

// ✅ ฟังก์ชัน 1: แก้ไขเฉพาะชื่อ (Name)
func UpdateUserProfileName(c *gin.Context) {
	// 1. ดึง User ID จาก Middleware
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// 2. รับค่า JSON
	var input UpdateNameInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input: name is required"})
		return
	}

	// 3. อัปเดตลง Database (ตาราง user_profiles คอลัมน์ name)
	query := `UPDATE public.user_profiles SET name = $1 WHERE id = $2`
	
	// ใช้ config.DB ที่ประกาศไว้ใน package configs
	_, err := configs.DB.Exec(context.Background(), query, input.Name, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update name: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Name updated successfully",
		"name":    input.Name,
	})
}

// ✅ ฟังก์ชัน 2: แก้ไขเฉพาะ Bio (Detail)
func UpdateUserProfileBio(c *gin.Context) {
	// 1. ดึง User ID จาก Middleware
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// 2. รับค่า JSON
	var input UpdateBioInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input: bio is required"})
		return
	}

	// 3. อัปเดตลง Database (ตาราง user_profiles คอลัมน์ detail)
	// หมายเหตุ: ใน struct UserProfile คุณใช้ชื่อ Detail ซึ่งมักจะ map กับ column "detail" ใน DB
	query := `UPDATE public.user_profiles SET detail = $1 WHERE id = $2`

	_, err := configs.DB.Exec(context.Background(), query, input.Bio, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update bio: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Bio updated successfully",
		"bio":     input.Bio,
	})
}