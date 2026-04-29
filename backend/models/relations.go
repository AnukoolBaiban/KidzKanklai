package models

import (
	"time"
	"github.com/google/uuid"
)

// Table: conduct (User <-> Exam)
type Conduct struct {
	UserID        uuid.UUID  `json:"user_id"`
	ExamID        int64      `json:"exam_id"`
	Status        *string    `json:"status"`
	CompletedDate *time.Time `json:"completed_date"`
}

// Table: get_notifications (User <-> Notification)
type GetNotification struct {
	UserID         uuid.UUID  `json:"user_id"`
	NotificationID int64      `json:"notification_id"`
	Status         *string    `json:"status"`
	ReadDate       *time.Time `json:"read_date"`
	RewardClaimed  *bool      `json:"reward_claimed"`
}

// Table: take (Exam <-> Item)
type Take struct {
	ExamID        int64      `json:"exam_id"`
	ItemID        int64      `json:"item_id"`
	Quantity      *int       `json:"quantity"` // 🌟 เพิ่มบรรทัดนี้
}

// Table: wear (Character <-> Item)
type Wear struct {
	CharacterID int64   `json:"character_id"`
	ItemID      int64   `json:"item_id"`
	Type        *string `json:"type"`
}

// Table: obtain (Notification <-> Item)
type Obtain struct {
	NotificationID int64      `json:"notification_id"`
	ItemID         int64      `json:"item_id"`
	Status         *string    `json:"status"`
	CompletedDate  *time.Time `json:"completed_date"`
	RewardClaimed  *bool      `json:"reward_claimed"`
}

// Table: do_quests (User <-> Quest)
type DoQuest struct {
	UserID        uuid.UUID  `json:"user_id"`
	QuestID       int64      `json:"quest_id"`
	Status        *string    `json:"status"`
	CompletedDate *time.Time `json:"completed_date"`
	Progress      *int       `json:"progress"` // 🌟 เพิ่มบรรทัดนี้

	// 🌟 เพิ่มบรรทัดด้านล่างนี้
    Score           *int       `json:"score"`             // เก็บขะแนนที่ทำได้ล่าสุด
    LastAttemptDate *time.Time `json:"last_attempt_date"` // เวลาที่กดทำเควสครั้งล่าสุด (ใช้คำนวณ Cooldown 10 นาที)
}

// Table: collect (User <-> Item - Inventory)
type Collect struct {
	UserID       uuid.UUID  `json:"user_id"`
	ItemID       int64      `json:"item_id"`
	Quantity     *int       `json:"quantity"`
	AcquiredDate *time.Time `json:"acquired_date"`
}

// Table: attain (User <-> Achievement)
type Attain struct {
	UserID        uuid.UUID  `json:"user_id"`
	AchievementID int64      `json:"achievement_id"`
	Status        *string    `json:"status"`
	CompletedDate *time.Time `json:"completed_date"`
	RewardClaimed *bool      `json:"reward_claimed"`
}

// Table: give (Achievement <-> Item)
type Give struct {
	AchievementID int64      `json:"achievement_id"`
	ItemID        int64      `json:"item_id"`
	Quantity      *int       `json:"quantity"`
	AcquiredDate  *time.Time `json:"acquired_date"`
}

// Table: receive (Quest <-> Item)
type Receive struct {
	QuestID  int64 `json:"quest_id"`
	ItemID   int64 `json:"item_id"`
	Quantity *int  `json:"quantity"`
}