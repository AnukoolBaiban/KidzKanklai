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
		id           string // UUID
		email        string
		username     string
		bio          string
		level        int
		exp          int
		bodyType     string
		intelligence int
		strength     int
		creative     int
	)
	// Initialize variables to avoid null issues
	username = ""
	bio = ""
	email = ""
	bodyType = "KID"

	// Query main data
	query := `
		SELECT 
			u.id::text, u.email, COALESCE(u.name, ''), COALESCE(u.detail, ''),
			c.level, c.experience, COALESCE(c.body_type, 'KID'),
			c.intelligence, c.strength, c.creative
		FROM public.user_profiles u
		LEFT JOIN public.characters c ON u.id = c.user_id
		WHERE u.id = $1
	`
	// Note: u.id is uuid, casting to text for scan
	err := configs.DB.QueryRow(ctx, query, userId).Scan(
		&id, &email, &username, &bio,
		&level, &exp, &bodyType,
		&intelligence, &strength, &creative,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch profile: " + err.Error()})
		return
	}

	// 2. Get Equipped Items
	// We need to map them to: equipped_skin, equipped_hair, equipped_face
	equipped := map[string]string{
		"Skin": "", "Hair": "", "Face": "", "Outfit": "",
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
		"id":              id,
		"email":           email,
		"username":        username,
		"bio":             bio,
		"level":           level,
		"exp":             exp,
		"body_type":       bodyType,
		"stat_intellect":  intelligence,
		"stat_strength":   strength,
		"stat_creativity": creative,
		"equipped_skin":   equipped["Skin"],
		"equipped_hair":   equipped["Hair"],
		"equipped_face":   equipped["Face"],
		"equipped_outfit": equipped["Outfit"],
	})
}

// API: Update Body Type (Kid/Teen/Adult)
type UpdateBodyTypeRequest struct {
	BodyType string `json:"body_type" binding:"required"`
}

func UpdateBodyType(c *gin.Context) {
	userId, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req UpdateBodyTypeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate body type
	bodyType := strings.ToUpper(req.BodyType)
	if bodyType != "KID" && bodyType != "TEEN" && bodyType != "ADULT" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid body type"})
		return
	}

	ctx := context.Background()

	// Update characters table
	query := `UPDATE public.characters SET body_type = $1 WHERE user_id = $2`
	_, err := configs.DB.Exec(ctx, query, bodyType, userId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update body type: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Body type updated successfully", "body_type": bodyType})
}
