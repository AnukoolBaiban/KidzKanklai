package main

import (
	"backend/configs"
	"backend/handlers"

	"github.com/gin-gonic/gin"
)

func main() {
	// 1. เชื่อมต่อฐานข้อมูล
	configs.ConnectDB()

	// //config.ResetDatabase() // Drop และ Create ตารางพร้อมเปิด RLS + Policies ตามปกติ
	// //config.DisableRLS()    // ปิด RLS + ลบ Policies ทั้งหมด

	// 2. เริ่มระบบ Auth
	handlers.InitAuth()

	// 3. เริ่ม Server
	r := gin.Default()

	// CORS Middleware — อนุญาตให้ Flutter Web (Chrome) เรียก API ได้
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	auth := r.Group("/")
	auth.Use(handlers.AuthMiddleware)
	auth.GET("/me", handlers.Me)

	// --- Routes ใหม่ (เพิ่มตรงนี้) ---
	// Endpoint สำหรับแก้ชื่อ
	auth.PUT("/profile/name", handlers.UpdateUserProfileName)

	// Endpoint สำหรับแก้ Bio
	auth.PUT("/profile/bio", handlers.UpdateUserProfileBio)

	// Endpoint สำหรับเปลี่ยนร่าง (Kid/Teen/Adult)
	auth.PUT("/profile/body-type", handlers.UpdateBodyType)

	// --- Fashion System ---
	auth.GET("/inventory", handlers.GetInventory)
	auth.POST("/equip", handlers.EquipItem)
	auth.GET("/equipped", handlers.GetEquippedItems)
	
	// --- Gacha System ---
	auth.POST("/gacha/pull", handlers.PullGacha)
	auth.GET("/gacha/rates", handlers.GetGachaRates)

	// --- Rewards ---
	auth.POST("/rewards/login-bonus", handlers.ClaimLoginTickets)

	auth.POST("/rewards/claim-achievement", handlers.ClaimAchievementReward)

	// --- AI ---
	auth.POST("/ai/dialogue", handlers.GenerateDialogue)
	// --- Quests ---
	auth.POST("/quests/create", handlers.CreateNormalQuest)
	auth.POST("/quests/complete", handlers.CompleteNormalQuest)
	auth.POST("/quests/cancel", handlers.CancelQuest)
	auth.POST("/quests/instant/start", handlers.StartInstantQuest)
	auth.POST("/quests/instant/complete", handlers.CompleteInstantQuest)
	auth.POST("/quests/system/init", handlers.InitSystemQuests)
	auth.POST("/quests/system/complete", handlers.CompleteSystemQuest)

	// 🌟 เพิ่มบรรทัดนี้ เพื่อให้ Go รู้จัก API สถานที่
	auth.POST("/locations/action", handlers.PerformLocationAction)

	auth.POST("/exams/generate-weekly", handlers.GenerateWeeklyExams)
	auth.POST("/exams/start", handlers.StartExam)
	// --- Notifications ---
	auth.GET("/notifications", handlers.GetNotifications)
	auth.PUT("/notifications/:id/read", handlers.MarkNotificationRead)
	auth.DELETE("/notifications/:id", handlers.DeleteNotification)
	auth.DELETE("/notifications", handlers.DeleteAllNotifications)

	// --- Clubs ---
	auth.POST("/clubs/create", handlers.CreateClub)
	auth.POST("/clubs/join", handlers.JoinClub)
	auth.POST("/clubs/leave", handlers.LeaveClub)
	auth.POST("/clubs/kick", handlers.KickMember)
	auth.POST("/clubs/delete", handlers.DeleteClub)

	auth.POST("/clubs/quests/create", handlers.CreateClubQuest)
	auth.GET("/clubs/quests", handlers.GetClubQuests)
	auth.POST("/clubs/quests/submit", handlers.SubmitClubQuest)

	r.Run(":8080")
}
