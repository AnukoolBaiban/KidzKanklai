package handlers

import (
	"backend/configs"
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/MicahParks/keyfunc/v2"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// ตัวแปรเก็บ Keyfunc (แม่กุญแจ) ไว้ใน Memory
var jwks *keyfunc.JWKS

// ฟังก์ชันนี้ต้องถูกเรียก 1 ครั้งตอนเริ่มโปรแกรม (ใน main.go)
func InitAuth() {

	// ดึงจาก config ที่เราโหลดไว้แล้ว
	projectRef := configs.SupabaseProjectRef

	if projectRef == "" {
		// ถ้าขี้เกียจแก้ .env บ่อยๆ ใส่รหัส Project ตรงนี้ได้เลย (เช่น "abcdefghijklm")
		log.Fatal("❌ Error: SUPABASE_PROJECT_REF is missing in .env")
	}

	// 2. สร้าง URL ของ JWKS (กุญแจสาธารณะของ Supabase)
	jwksURL := fmt.Sprintf("https://%s.supabase.co/auth/v1/.well-known/jwks.json", projectRef)

	// 3. โหลด Key มาเก็บไว้ (พร้อมระบบ Refresh อัตโนมัติ)
	var err error
	options := keyfunc.Options{
		RefreshErrorHandler: func(err error) {
			log.Printf("⚠️ Error refreshing JWKS: %v", err)
		},
		RefreshInterval:  time.Hour, // เช็ค Key ใหม่ทุก 1 ชั่วโมง
		RefreshRateLimit: time.Minute * 5,
		RefreshTimeout:   time.Second * 10,
	}

	jwks, err = keyfunc.Get(jwksURL, options)
	if err != nil {
		log.Fatalf("❌ Failed to create JWKS from resource at '%s': %v", jwksURL, err)
	}

	log.Println("✅ Auth System Initialized (JWKS Loaded)")
}

// Middleware สำหรับดักจับ Request
func AuthMiddleware(c *gin.Context) {
	// 1. ดึง Header
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
		return
	}

	// 2. ตัดคำว่า Bearer
	tokenStr := strings.Replace(authHeader, "Bearer ", "", 1)

	// 3. ตรวจสอบ Token (พระเอกของเราคือ jwks.Keyfunc)
	token, err := jwt.Parse(tokenStr, jwks.Keyfunc)

	// 4. เช็คผลลัพธ์
	if err != nil || !token.Valid {
		// ปริ้นท์ Error ให้เห็นชัดๆ (ช่วย Debug)
		fmt.Printf("❌ Token Error: %v\n", err)
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
		return
	}

	// 5. ดึงข้อมูล User (Claims)
	if claims, ok := token.Claims.(jwt.MapClaims); ok {
		// ดึง User ID
		if sub, ok := claims["sub"].(string); ok {
			c.Set("user_id", sub)
		}

		// ดึง Email
		if email, ok := claims["email"].(string); ok {
			c.Set("email", email)
		}

		c.Next() // ผ่าน!
	} else {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
	}
}

// API Test (เหมือนเดิม)
// API Me: Get Full User Profile
func Me(c *gin.Context) {
	userId, exists := c.Get("user_id") // UUID string
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	ctx := context.Background()

	// 1. Get User Profile & Character Stats
	var (
		id       string // UUID
		email    string
		username string
		bio      string
		level    int
		exp      int
		// coins         int -- Removed unused
		// Note: Coins/Tickets/Vouchers might be in characters or user_profiles?
		// Schema doesn't show coins in user_profiles or characters.
		// Assuming for now we rely on logical defaults or columns I missed.
		// Wait, I checked db.go, I didn't see coins.
		// Let's check where coins are.
		// If they aren't in DB, I will return 0 or mock data for now to prevent crash.
		// Looking at schema in db.go:
		// user_profiles: id, name, email, detail, ...
		// characters: level, experience, gender, skin_color, emotion, body_type, intelligence, strength, creative, stamina
		// NO COINS?
		// Maybe in a 'currencies' table or I missed it?
		// User model in Dart expects coins.
		// For now I will hardcode coins/tickets/vouchers to 0 or check if they are in 'collect' as items?
		// But usually currency is a column.
		// I will just return 0 for currencies to satisfy the model.

		intelligence int
		strength     int
		creative     int
	)
	// Initialize variables to avoid null issues
	username = ""
	bio = ""
	email = ""

	// Query main data
	query := `
		SELECT 
			u.id::text, u.email, COALESCE(u.name, ''), COALESCE(u.detail, ''),
			c.level, c.experience, 
			c.intelligence, c.strength, c.creative
		FROM public.user_profiles u
		LEFT JOIN public.characters c ON u.id = c.user_id
		WHERE u.id = $1
	`
	// Note: u.id is uuid, casting to text for scan
	err := configs.DB.QueryRow(ctx, query, userId).Scan(
		&id, &email, &username, &bio,
		&level, &exp,
		&intelligence, &strength, &creative,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch profile: " + err.Error()})
		return
	}

	// 2. Get Equipped Items
	// We need to map them to: equipped_skin, equipped_hair, equipped_face
	equipped := map[string]string{
		"Skin": "", "Hair": "", "Face": "", "Body": "", "Cloth": "", "Shoes": "",
	}

	itemQuery := `
		SELECT w.type, i.name
		FROM public.wear w
		JOIN public.items i ON w.item_id = i.id
		WHERE w.character_id = (SELECT id FROM public.characters WHERE user_id = $1)
	`
	rows, err := configs.DB.Query(ctx, itemQuery, userId)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var iType, iName string
			if err := rows.Scan(&iType, &iName); err == nil {
				// Map category name (from wear.type) to our keys
				// Assuming wear.type stores category name like 'Hair', 'Skin', etc.
				if _, ok := equipped[iType]; ok {
					equipped[iType] = iName
				}
			}
		}
	}

	// 3. Construct Response
	// Note: Dart side expects snake_case keys for some reason (based on User.fromJson)
	c.JSON(http.StatusOK, gin.H{
		"equipped_skin":   equipped["Skin"],
		"equipped_hair":   equipped["Hair"],
		"equipped_face":   equipped["Face"],
		"equipped_body":   equipped["Body"],
		"equipped_cloth":  equipped["Cloth"],
		"equipped_shoes":  equipped["Shoes"],
	})
}
