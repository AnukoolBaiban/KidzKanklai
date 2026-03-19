package models

import "time"

// Table: quests
type Quest struct {
	ID        int64      `json:"id"`
	Name      string     `json:"name"`
	Detail    *string    `json:"detail"`
	Image     *string    `json:"image"`
	StartDate *time.Time `json:"start_date"`
	DueDate   *time.Time `json:"due_date"`
	Type      *string    `json:"type"`
	ClubID    *int64     `json:"club_id"` // FK
	TargetAmount *int       `json:"target_amount"` // 🌟 เพิ่มบรรทัดนี้
}

// Table: exams
type Exam struct {
	ID     int64   `json:"id"`
	Name   string  `json:"name"`
	Detail *string `json:"detail"`
	Status *string `json:"status"`
	Type   *string `json:"type"`
	Image  *string `json:"image"`
	MapID  *int64  `json:"map_id"` // FK
}

// Table: maps
type Map struct {
	ID     int64   `json:"id"`
	Name   string  `json:"name"`
	Detail *string `json:"detail"` // ใช้ Pointer เพราะใน DB เป็น NULL ได้
	Image  *string `json:"image"`
}