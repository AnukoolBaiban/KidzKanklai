package main

import (
	"backend/configs"
	"backend/handlers"

	"github.com/gin-gonic/gin"
)

func main() {
	// 1. เชื่อมต่อฐานข้อมูล
	configs.ConnectDB()

	// config.ResetDatabase() // Drop และ Create ตารางพร้อมเปิด RLS + Policies ตามปกติ
	// config.DisableRLS()    // ปิด RLS + ลบ Policies ทั้งหมด

	// 2. เริ่มระบบ Auth
	handlers.InitAuth()

	// 3. เริ่ม Server
	r := gin.Default()

	auth := r.Group("/")
	auth.Use(handlers.AuthMiddleware)
	auth.GET("/me", handlers.Me)

	// --- Routes ใหม่ (เพิ่มตรงนี้) ---
	// Endpoint สำหรับแก้ชื่อ
	auth.PUT("/profile/name", handlers.UpdateUserProfileName)

	// Endpoint สำหรับแก้ Bio
	auth.PUT("/profile/bio", handlers.UpdateUserProfileBio)

	// --- Fashion System ---
	auth.GET("/inventory", handlers.GetInventory)
	auth.POST("/equip", handlers.EquipItem)
	auth.GET("/equipped", handlers.GetEquippedItems)

	// --- Rewards ---
	auth.POST("/rewards/login-bonus", handlers.ClaimLoginTickets)
	auth.POST("/rewards/add-coins", handlers.AddTestCoins) 
	auth.POST("/rewards/claim-achievement", handlers.ClaimAchievementReward)

	r.Run(":8080")
}
