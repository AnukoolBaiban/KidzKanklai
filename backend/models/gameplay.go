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

	// 🌟 เพิ่มบรรทัดด้านล่างนี้
    PassingScore  *int       `json:"passing_score"`  // คะแนนขั้นต่ำที่ต้องผ่าน
    OwnerRewarded *bool      `json:"owner_rewarded"` // เช็คว่าปลายสัปดาห์แจกรางวัลให้หัวหน้าไปหรือยัง (กันแจกเบิ้ล)
}

// 🌟 สร้างตารางใหม่: quest_questions (Quest <-> Question)
type QuestQuestion struct {
    ID            int64   `json:"id"`
    QuestID       int64   `json:"quest_id"` // FK โยงไปหา Quest
    QuestionText  string  `json:"question_text"`
    ChoiceA       string  `json:"choice_a"`
    ChoiceB       string  `json:"choice_b"`
    ChoiceC       string  `json:"choice_c"`
    ChoiceD       string  `json:"choice_d"`
    CorrectAnswer string  `json:"correct_answer"` // เก็บค่า 'A', 'B', 'C', 'D'
}

// Table: exams
type Exam struct {
	ID     		 int64     `json:"id"`
	Name   		 string    `json:"name"`
	Detail 		 *string   `json:"detail"`
	Type   		 *string   `json:"type"`
	Intelligence int       `json:"intelligence"` // 🌟 เพิ่มบรรทัดนี้
	Strength     int       `json:"strength"` 	 // 🌟 เพิ่มบรรทัดนี้
	Creative     int       `json:"creative"` 	 // 🌟 เพิ่มบรรทัดนี้
	Stamina      int       `json:"stamina"` 	 // 🌟 เพิ่มบรรทัดนี้
	Status 		 *string   `json:"status"` 
	Image  		 *string   `json:"image"`
	MapID  		 *int64    `json:"map_id"` // FK 
}

// Table: maps
type Map struct {
	ID     int64   `json:"id"`
	Name   string  `json:"name"`
	Detail *string `json:"detail"` // ใช้ Pointer เพราะใน DB เป็น NULL ได้
	Image  *string `json:"image"`
}