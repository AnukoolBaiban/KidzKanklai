package models

import (
	"time"

	"github.com/google/uuid"
)

// Table: user_profiles
type UserProfile struct {
	ID           uuid.UUID  `json:"id"` // PK linked to auth.users
	Name         *string    `json:"name"`
	Email        *string    `json:"email"`
	Detail       *string    `json:"detail"`
	CreatedAt    *time.Time `json:"created_at"`
	ClubID       *int64     `json:"club_id"` // FK (Nullable)
	ClubJoinDate *time.Time `json:"club_join_date"`
	ClubRole     *string    `json:"club_role"`
}

// Table: characters
type Character struct {
	ID           int64     `json:"id"`
	UserID       uuid.UUID `json:"user_id"` // FK (Unique)
	Level        int       `json:"level"`
	Experience   int       `json:"experience"`
	Gender       *string   `json:"gender"`
	SkinColor    *string   `json:"skin_color"`
	Emotion      *string   `json:"emotion"`
	BodyType     *string   `json:"body_type"`
	Intelligence int       `json:"intelligence"`
	Strength     int       `json:"strength"`
	Creative     int       `json:"creative"`
	Stamina      int       `json:"stamina"`
}

// Table: clubs
type Club struct {
	ID          int64      `json:"id"`
	Name        string     `json:"name"`
	Description *string    `json:"description"`
	InviteCode  string     `json:"invite_code"` // 🌟 เพิ่มใหม่: รหัสเข้าร่วมชมรม (e.g., ABCDEF)
	CreatedAt   *time.Time `json:"created_at"`
	IsJoinable  bool       `json:"is_joinable"` // 🌟 เพิ่มใหม่: เช็คว่าชมรมเปิดรับสมาชิกใหม่หรือไม่ (true/false)
}

// Table: achievements
type Achievement struct {
	ID          int64   `json:"id"`
	Name        string  `json:"name"`
	Description *string `json:"description"`
	Image       *string `json:"image"`
}

// Table: notifications
type Notification struct {
	ID        int64      `json:"id"`
	Title     string     `json:"title"`
	Detail    *string    `json:"detail"`
	Type      *string    `json:"type"`
	Image     *string    `json:"image"`
	StartDate *time.Time `json:"start_date"`
	DueDate   *time.Time `json:"due_date"`
}
