package handlers

import (
	"backend/configs"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ------------------------------------------------------------------------
// Helper: คำนวณหาวันจันทร์ถัดไป เวลาเที่ยงคืนตรง (UTC+7)
// ------------------------------------------------------------------------
func getNextMondayMidnightUTC7() time.Time {
	loc, err := time.LoadLocation("Asia/Bangkok") // UTC+7
	if err != nil {
		loc = time.FixedZone("UTC+7", 7*60*60)
	}

	now := time.Now().In(loc)
	
	// หาวันที่ต้องบวกเพิ่มเพื่อให้ถึงวันจันทร์ถัดไป
	daysUntilMonday := int(time.Monday - now.Weekday())
	if daysUntilMonday <= 0 {
		daysUntilMonday += 7 // ถ้าวันนี้เป็นวันจันทร์-อาทิตย์ ให้ปัดไปจันทร์หน้า
	}

	nextMonday := now.AddDate(0, 0, daysUntilMonday)
	// เซ็ตเวลาเป็น 00:00:00
	return time.Date(nextMonday.Year(), nextMonday.Month(), nextMonday.Day(), 0, 0, 0, 0, loc)
}

// ------------------------------------------------------------------------
// API 1: สร้างภารกิจและคำถาม (Create Quest)
// ------------------------------------------------------------------------

type QuestionInput struct {
	QuestionText  string `json:"question_text" binding:"required"`
	ChoiceA       string `json:"choice_a" binding:"required"`
	ChoiceB       string `json:"choice_b" binding:"required"`
	ChoiceC       string `json:"choice_c" binding:"required"`
	ChoiceD       string `json:"choice_d" binding:"required"`
	CorrectAnswer string `json:"correct_answer" binding:"required"` // A, B, C, D
}

type CreateQuestInput struct {
	Name         string          `json:"name" binding:"required"`
	Detail       string          `json:"detail"`
	PassingScore int             `json:"passing_score" binding:"required"`
	Questions    []QuestionInput `json:"questions" binding:"required"`
}

// ------------------------------------------------------------------------
// API: สร้างภารกิจชมรมพร้อมอัปโหลดรูปภาพ (Create Club Quest)
// ------------------------------------------------------------------------
// POST /clubs/quests/create
func CreateClubQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, _ := uuid.Parse(userIDStr)

	// 🌟 1. รับค่าแบบ Multipart Form-Data
	name := c.PostForm("name")
	detail := c.PostForm("detail")
	passingScoreStr := c.PostForm("passing_score")
	questionsStr := c.PostForm("questions") // รับเป็น JSON String

	if name == "" || passingScoreStr == "" || questionsStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ข้อมูลไม่ครบถ้วน (ต้องการ name, passing_score, questions)"})
		return
	}

	passingScore, err := strconv.Atoi(passingScoreStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คะแนนขั้นต่ำต้องเป็นตัวเลข"})
		return
	}

	// 🌟 2. แปลง JSON String ของคำถาม ให้กลับเป็น Struct Array
	var questions []QuestionInput
	err = json.Unmarshal([]byte(questionsStr), &questions)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "รูปแบบคำถาม (questions) ไม่ถูกต้อง"})
		return
	}

	if len(questions) < 1 || len(questions) > 10 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "จำนวนคำถามต้องอยู่ระหว่าง 1 ถึง 10 ข้อ"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 3. ตรวจสอบสิทธิ์ (ต้องเป็น Owner ของชมรม)
	var clubID int64
	var clubRole string
	err = tx.QueryRow(ctx, `SELECT club_id, club_role FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == 0 || clubRole != "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เฉพาะหัวหน้าชมรมเท่านั้นที่สามารถสร้างภารกิจได้"})
		return
	}

	// 🌟 4. ตรวจสอบโควต้า (สร้างได้ไม่เกิน 3 ภารกิจต่อสัปดาห์)
	var currentWeekQuestCount int
	countQuery := `
		SELECT COUNT(*) FROM public.quests 
		WHERE club_id = $1 AND start_date >= date_trunc('week', current_date)
	`
	tx.QueryRow(ctx, countQuery, clubID).Scan(&currentWeekQuestCount)
	if currentWeekQuestCount >= 3 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "สร้างภารกิจครบ 3 ครั้งในสัปดาห์นี้แล้ว"})
		return
	}

	// 🌟 5. จัดการอัปโหลดรูปภาพไปยัง Cloudinary (เหมือน NormalQuest)
	var imageUrlPtr *string
	file, _, err := c.Request.FormFile("image")
	if err == nil {
		defer file.Close()
		cloudinaryURL := os.Getenv("CLOUDINARY_URL")
		if cloudinaryURL == "" {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Server configuration error"})
			return
		}
		cld, err := cloudinary.NewFromURL(cloudinaryURL)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to initialize Cloudinary"})
			return
		}
		resp, err := cld.Upload.Upload(ctx, file, uploader.UploadParams{
			Folder: "KidzKanKlai/club_quests", // เปลี่ยนโฟลเดอร์ให้เป็นของชมรม
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload image"})
			return
		}
		url := resp.SecureURL
		imageUrlPtr = &url
	}

	// 🌟 6. จัดการรายละเอียดภารกิจ (Detail) ถ้าเป็นค่าว่างให้เป็น Nil Pointer
	var detailPtr *string
	if detail != "" {
		detailPtr = &detail
	}

	// 🌟 7. สร้างภารกิจ (กำหนดวันหมดเขตเป็นวันจันทร์หน้า)
	startDate := time.Now()
	dueDate := getNextMondayMidnightUTC7()
	var newQuestID int64
	questType := "ชมรม" // ระบุประเภท

	insertQuestQuery := `
		INSERT INTO public.quests (name, detail, image, start_date, due_date, type, club_id, passing_score, owner_rewarded)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, false) RETURNING id
	`
	err = tx.QueryRow(ctx, insertQuestQuery, name, detailPtr, imageUrlPtr, startDate, dueDate, questType, clubID, passingScore).Scan(&newQuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "สร้างภารกิจล้มเหลว"})
		return
	}

	// 🌟 8. บันทึกคำถามลงตาราง quest_questions
	for _, q := range questions {
		insertQuestionQuery := `
			INSERT INTO public.quest_questions (quest_id, question_text, choice_a, choice_b, choice_c, choice_d, correct_answer)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`
		_, err = tx.Exec(ctx, insertQuestionQuery, newQuestID, q.QuestionText, q.ChoiceA, q.ChoiceB, q.ChoiceC, q.ChoiceD, q.CorrectAnswer)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "บันทึกคำถามล้มเหลว"})
			return
		}
	}

	// 🌟 9. ตั้งค่าของรางวัลแบบ Fix ตายตัว ลงตาราง receive
	insertRewardQuery := `INSERT INTO public.receive (quest_id, item_id, quantity) VALUES ($1, 20, 1000), ($1, 22, 100)`
	_, err = tx.Exec(ctx, insertRewardQuery, newQuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "บันทึกของรางวัลล้มเหลว"})
		return
	}

	tx.Commit(ctx)
	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"message":   "สร้างภารกิจสำเร็จ!",
		"quest_id":  newQuestID,
		"due_date":  dueDate,
		"image_url": imageUrlPtr,
	})
}


// ------------------------------------------------------------------------
// API 2: ดึงรายการภารกิจของชมรม (Get Club Quests)
// ------------------------------------------------------------------------

// GET /clubs/quests
func GetClubQuests(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, _ := uuid.Parse(userIDStr)

	ctx := context.Background()

	// 🌟 1. เช็คคลับของผู้เล่น
	var clubID int64
	var clubRole string
	err := configs.DB.QueryRow(ctx, `SELECT COALESCE(club_id, 0), COALESCE(club_role, '') FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณยังไม่มีชมรม"})
		return
	}

	// 🌟 2. ดึงเควสที่ยังไม่หมดเขต + เช็คประวัติการทำเควส (เพิ่ม q.image เข้าไปใน SELECT)
	query := `
		SELECT q.id, q.name, q.detail, q.image, q.due_date, q.passing_score,
		       COALESCE(dq.status, 'pending') AS user_status,
		       dq.last_attempt_date
		FROM public.quests q
		LEFT JOIN public.do_quests dq ON q.id = dq.quest_id AND dq.user_id = $1
		WHERE q.club_id = $2 AND q.due_date > NOW()
		ORDER BY q.start_date DESC
	`
	rows, err := configs.DB.Query(ctx, query, userID, clubID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ดึงข้อมูลล้มเหลว"})
		return
	}
	defer rows.Close()

	var quests []map[string]interface{}
	now := time.Now()

	for rows.Next() {
		var id int64
		var name, detail, userStatus string
		var imagePtr *string // 🌟 รับค่า image แบบ Pointer (เผื่อไม่มีรูป)
		var dueDate time.Time
		var passingScore int
		var lastAttempt *time.Time

		// 🌟 Scan ข้อมูลเรียงตาม Query
		rows.Scan(&id, &name, &detail, &imagePtr, &dueDate, &passingScore, &userStatus, &lastAttempt)

		// 🌟 จัดการสถานะภาพ (แปลง Pointer ให้ใช้ใน JSON ง่ายขึ้น)
		var imageURL string
		if imagePtr != nil {
			imageURL = *imagePtr
		}

		// 🌟 3. จัดการสถานะ และคำนวณ Cooldown สำหรับ Member
		displayStatus := userStatus
		var cooldownSeconds int = 0

		if clubRole == "owner" {
			displayStatus = "owner" // หัวหน้าทำไม่ได้ ให้ UI ปิดปุ่ม
		} else if userStatus == "failed" && lastAttempt != nil {
			// เช็ค Cooldown 10 นาที (600 วินาที)
			timeSinceLastAttempt := now.Sub(*lastAttempt)
			if timeSinceLastAttempt < 10*time.Minute {
				displayStatus = "cooldown"
				cooldownSeconds = int(((10 * time.Minute) - timeSinceLastAttempt).Seconds())
			} else {
				displayStatus = "ready_to_retry"
			}
		}

		quests = append(quests, map[string]interface{}{
			"id":               id,
			"name":             name,
			"detail":           detail,
			"image":            imageURL, // 🌟 เพิ่ม image เข้าไปใน Response (ถ้าไม่มีรูปจะเป็น string ว่าง "")
			"due_date":         dueDate,
			"passing_score":    passingScore,
			"status":           displayStatus,
			"cooldown_seconds": cooldownSeconds,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"role":    clubRole,
		"quests":  quests,
	})
}

// ------------------------------------------------------------------------
// API 3: ส่งคำตอบและตรวจภารกิจชมรม (Submit Club Quest)
// ------------------------------------------------------------------------

type SubmitAnswerInput struct {
	QuestionID int64  `json:"question_id" binding:"required"`
	Answer     string `json:"answer" binding:"required"` // A, B, C, D
}

type SubmitQuestInput struct {
	QuestID int64               `json:"quest_id" binding:"required"`
	Answers []SubmitAnswerInput `json:"answers" binding:"required"`
}

// POST /clubs/quests/submit
func SubmitClubQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, _ := uuid.Parse(userIDStr)

	var input SubmitQuestInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ข้อมูลไม่ครบถ้วน"})
		return
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 1. ตรวจสอบสิทธิ์และดึงข้อมูลชมรม
	var clubID int64
	var clubRole string
	err = tx.QueryRow(ctx, `SELECT COALESCE(club_id, 0), COALESCE(club_role, '') FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "คุณยังไม่มีชมรม"})
		return
	}

	if clubRole == "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เจ้าของชมรมไม่สามารถทำภารกิจของชมรมตัวเองได้"})
		return
	}

	// 🌟 2. ดึงข้อมูลเควส (ต้องยังไม่หมดเขต)
	var passingScore int
	var questClubID int64
	err = tx.QueryRow(ctx, `SELECT club_id, passing_score FROM public.quests WHERE id = $1 AND due_date > NOW()`, input.QuestID).Scan(&questClubID, &passingScore)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ไม่พบภารกิจนี้ หรือภารกิจหมดเวลาไปแล้ว"})
		return
	}

	if clubID != questClubID {
		c.JSON(http.StatusForbidden, gin.H{"error": "คุณไม่สามารถทำภารกิจของชมรมอื่นได้"})
		return
	}

	// 🌟 3. ตรวจสอบประวัติการทำเควส (เช็ค Cooldown)
	var currentStatus string
	var lastAttempt *time.Time
	err = tx.QueryRow(ctx, `SELECT status, last_attempt_date FROM public.do_quests WHERE user_id = $1 AND quest_id = $2 FOR UPDATE`, userID, input.QuestID).Scan(&currentStatus, &lastAttempt)

	if err == nil {
		if currentStatus == "completed" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "คุณทำภารกิจนี้สำเร็จไปแล้ว"})
			return
		}
		if currentStatus == "failed" && lastAttempt != nil {
			// เช็ค Cooldown 10 นาที
			timeSinceLastAttempt := time.Since(*lastAttempt)
			if timeSinceLastAttempt < 10*time.Minute {
				timeLeft := int((10 * time.Minute) - timeSinceLastAttempt)
				c.JSON(http.StatusBadRequest, gin.H{
					"error":            fmt.Sprintf("คุณต้องรออีก %d วินาที ถึงจะตอบคำถามใหม่ได้", timeLeft/int(time.Second)),
					"cooldown_seconds": timeLeft / int(time.Second),
				})
				return
			}
		}
	}

	// 🌟 4. ตรวจคำตอบ (ดึงเฉลยจากฐานข้อมูลมาเช็ค)
	rows, err := tx.Query(ctx, `SELECT id, correct_answer FROM public.quest_questions WHERE quest_id = $1`, input.QuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "ดึงข้อมูลคำถามล้มเหลว"})
		return
	}
	defer rows.Close()

	// สร้าง Map เฉลยเพื่อความรวดเร็วในการตรวจ
	correctAnswersMap := make(map[int64]string)
	for rows.Next() {
		var qID int64
		var correctAns string
		rows.Scan(&qID, &correctAns)
		correctAnswersMap[qID] = correctAns
	}
	rows.Close() // ปิด connection ทันที

	// คำนวณคะแนน
	score := 0
	for _, userAns := range input.Answers {
		if correctAns, exists := correctAnswersMap[userAns.QuestionID]; exists {
			if userAns.Answer == correctAns {
				score++
			}
		}
	}

	// 🌟 5. ตรวจสอบว่าผ่านหรือไม่
	isPassed := score >= passingScore
	newStatus := "failed"
	if isPassed {
		newStatus = "completed"
	}

	// 🌟 6. อัปเดตประวัติการทำเควสลง do_quests (ใช้ UPSERT ป้องกันข้อมูลซ้ำ)
	upsertDoQuestQuery := `
		INSERT INTO public.do_quests (user_id, quest_id, status, score, last_attempt_date, completed_date)
		VALUES ($1, $2, $3, $4, NOW(), CASE WHEN $3 = 'completed' THEN NOW() ELSE NULL END)
		ON CONFLICT (user_id, quest_id) 
		DO UPDATE SET 
			status = EXCLUDED.status, 
			score = EXCLUDED.score, 
			last_attempt_date = EXCLUDED.last_attempt_date,
			completed_date = CASE WHEN EXCLUDED.status = 'completed' THEN NOW() ELSE public.do_quests.completed_date END;
	`
	_, err = tx.Exec(ctx, upsertDoQuestQuery, userID, input.QuestID, newStatus, score)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "บันทึกผลการทำภารกิจล้มเหลว"})
		return
	}

	// 🌟 7. ถ้าสอบผ่าน ให้แจกของรางวัล (จากตาราง receive -> collect)
	var rewards []map[string]interface{}
	if isPassed {
		rewardRows, err := tx.Query(ctx, `
			SELECT r.item_id, r.quantity, i.name 
			FROM public.receive r
			JOIN public.items i ON r.item_id = i.id
			WHERE r.quest_id = $1
		`, input.QuestID)

		if err == nil {
			type tempReward struct {
				ItemID int64
				Qty    int
				Name   string
			}
			var pendingRewards []tempReward

			for rewardRows.Next() {
				var itemID int64
				var qty int
				var name string
				if err := rewardRows.Scan(&itemID, &qty, &name); err == nil {
					pendingRewards = append(pendingRewards, tempReward{ItemID: itemID, Qty: qty, Name: name})
				}
			}
			rewardRows.Close()

			for _, item := range pendingRewards {
				if item.ItemID == 22 || item.Name == "EXP" {
					// ให้ EXP เข้าตัวละคร
					tx.Exec(ctx, `UPDATE public.characters SET experience = experience + $1 WHERE user_id = $2`, item.Qty, userID)
				} else {
					// ยัดของลงกระเป๋า Inventory
					tx.Exec(ctx, `
						INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
						VALUES ($1, $2, $3, NOW())
						ON CONFLICT (user_id, item_id) 
						DO UPDATE SET quantity = public.collect.quantity + EXCLUDED.quantity, acquired_date = NOW();
					`, userID, item.ItemID, item.Qty)
				}
				rewards = append(rewards, map[string]interface{}{"item_id": item.ItemID, "name": item.Name, "amount": item.Qty})
			}
		}
	}

	tx.Commit(ctx)

	go func(u uuid.UUID) {
		CheckCoinAchievement(context.Background(), u)
	}(userID)

	CheckLevelAchievement(ctx, userID)

	// สร้างตัวแปร msg ขึ้นมาก่อน
	msg := "คะแนนไม่ถึงเกณฑ์ กรุณารอ 10 นาที"
	if isPassed {
		msg = "ภารกิจสำเร็จ!"
	}

	// แล้วค่อยเอาไปใส่ใน c.JSON
	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"is_passed":     isPassed,
		"score":         score,
		"passing_score": passingScore,
		"rewards":       rewards,
		"message":       msg, // 🌟 ใช้ตัวแปรนี้แทน
	})
}
