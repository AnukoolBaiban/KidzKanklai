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
	"github.com/jackc/pgx/v5" // 🌟 เพิ่มบรรทัดนี้เข้าไป!
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)


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
	dueDateStr := c.PostForm("due_date") // รับค่าวันหมดเขตที่เลือกเอง
	passingScoreStr := c.PostForm("passing_score")
	questionsStr := c.PostForm("questions") 

	if name == "" || dueDateStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ข้อมูลไม่ครบถ้วน (ต้องการ name และ due_date)"})
		return
	}

	// 🌟 แปลงวันที่
	dueDate, err := time.Parse(time.RFC3339, dueDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "รูปแบบวันหมดเขต (due_date) ไม่ถูกต้อง"})
		return
	}

	passingScore := 0
	if passingScoreStr != "" {
		passingScore, _ = strconv.Atoi(passingScoreStr)
	}

	// 🌟 แปลงคำถาม (อนุญาตให้ไม่มีคำถามได้)
	var questions []QuestionInput
	if questionsStr != "" && questionsStr != "[]" {
		err = json.Unmarshal([]byte(questionsStr), &questions)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "รูปแบบคำถาม (questions) ไม่ถูกต้อง"})
			return
		}
		if len(questions) > 10 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "จำนวนคำถามต้องไม่เกิน 10 ข้อ"})
			return
		}
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 🌟 2. ตรวจสอบสิทธิ์ (ต้องเป็น Owner ของชมรม)
	var clubID int64
	var clubRole string
	err = tx.QueryRow(ctx, `SELECT club_id, club_role FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == 0 || clubRole != "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เฉพาะหัวหน้าชมรมเท่านั้นที่สามารถสร้างภารกิจได้"})
		return
	}

	// 🌟 3. ตรวจสอบตั๋ว Club (Item ID = 19)
	var ticketCount int
	err = tx.QueryRow(ctx, `SELECT quantity FROM public.collect WHERE user_id = $1 AND item_id = 19`, userID).Scan(&ticketCount)
	
	hasRewards := false
	if err == nil && ticketCount >= 1 {
		hasRewards = true
		// หักตั๋ว 1 ใบ
		tx.Exec(ctx, `UPDATE public.collect SET quantity = quantity - 1 WHERE user_id = $1 AND item_id = 19`, userID)
	}

	// 🌟 4. จัดการอัปโหลดรูปภาพไปยัง Cloudinary
	var imageUrlPtr *string
	file, _, err := c.Request.FormFile("image")
	if err == nil {
		defer file.Close()
		cloudinaryURL := os.Getenv("CLOUDINARY_URL")
		if cloudinaryURL != "" {
			cld, _ := cloudinary.NewFromURL(cloudinaryURL)
			resp, err := cld.Upload.Upload(ctx, file, uploader.UploadParams{
				Folder: "KidzKanKlai/club_quests", 
			})
			if err == nil {
				url := resp.SecureURL
				imageUrlPtr = &url
			}
		}
	}

	var detailPtr *string
	if detail != "" {
		detailPtr = &detail
	}

	// 🌟 5. สร้างภารกิจ
	startDate := time.Now()
	var newQuestID int64
	questType := "ชมรม" 

	insertQuestQuery := `
		INSERT INTO public.quests (name, detail, image, start_date, due_date, type, club_id, passing_score, owner_rewarded)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, false) RETURNING id
	`
	err = tx.QueryRow(ctx, insertQuestQuery, name, detailPtr, imageUrlPtr, startDate, dueDate, questType, clubID, passingScore).Scan(&newQuestID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "สร้างภารกิจล้มเหลว"})
		return
	}

	// 🌟 6. บันทึกคำถาม (ถ้ามี)
	for _, q := range questions {
		insertQuestionQuery := `
			INSERT INTO public.quest_questions (quest_id, question_text, choice_a, choice_b, choice_c, choice_d, correct_answer)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`
		tx.Exec(ctx, insertQuestionQuery, newQuestID, q.QuestionText, q.ChoiceA, q.ChoiceB, q.ChoiceC, q.ChoiceD, q.CorrectAnswer)
	}

	// 🌟 7. ตั้งค่าของรางวัล (เฉพาะถ้ามีตั๋ว)
	if hasRewards {
		insertRewardQuery := `INSERT INTO public.receive (quest_id, item_id, quantity) VALUES ($1, 20, 1000), ($1, 22, 100)`
		tx.Exec(ctx, insertRewardQuery, newQuestID)
	}

	tx.Commit(ctx)
	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"message":    "สร้างภารกิจสำเร็จ!",
		"quest_id":   newQuestID,
		"due_date":   dueDate,
		"image_url":  imageUrlPtr,
		"is_rewarded": hasRewards,
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
	Answers []SubmitAnswerInput `json:"answers"` // 🌟 ลบ binding ออกแล้ว
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

	// 1. ตรวจสอบสิทธิ์
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

	// 2. ดึงข้อมูลเควส
	var passingScore int
	var questClubID int64
	var questName string
	err = tx.QueryRow(ctx, `SELECT club_id, passing_score, name FROM public.quests WHERE id = $1 AND due_date > NOW()`, input.QuestID).Scan(&questClubID, &passingScore, &questName)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ไม่พบภารกิจนี้ หรือภารกิจหมดเวลาไปแล้ว"})
		return
	}
	if clubID != questClubID {
		c.JSON(http.StatusForbidden, gin.H{"error": "คุณไม่สามารถทำภารกิจของชมรมอื่นได้"})
		return
	}

	// 3. ตรวจสอบประวัติการทำเควส (Cooldown)
	var currentStatus string
	var lastAttempt *time.Time
	err = tx.QueryRow(ctx, `SELECT status, last_attempt_date FROM public.do_quests WHERE user_id = $1 AND quest_id = $2 FOR UPDATE`, userID, input.QuestID).Scan(&currentStatus, &lastAttempt)

	if err == nil {
		if currentStatus == "completed" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "คุณทำภารกิจนี้สำเร็จไปแล้ว"})
			return
		}
		if currentStatus == "failed" && lastAttempt != nil {
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

	// 4. ตรวจคำตอบ
	rows, _ := tx.Query(ctx, `SELECT id, correct_answer FROM public.quest_questions WHERE quest_id = $1`, input.QuestID)
	correctAnswersMap := make(map[int64]string)
	for rows.Next() {
		var qID int64
		var correctAns string
		rows.Scan(&qID, &correctAns)
		correctAnswersMap[qID] = correctAns
	}
	rows.Close()

	score := 0
	for _, userAns := range input.Answers {
		if correctAns, exists := correctAnswersMap[userAns.QuestionID]; exists && userAns.Answer == correctAns {
			score++
		}
	}

	// 5. ตรวจสอบว่าผ่านหรือไม่
	isPassed := score >= passingScore
	newStatus := "failed"
	if isPassed {
		newStatus = "completed"
	}

	// 6. อัปเดตประวัติการทำเควส
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
	tx.Exec(ctx, upsertDoQuestQuery, userID, input.QuestID, newStatus, score)

	var rewards []map[string]interface{}
	
	// 🌟 7. จัดการของรางวัลเมื่อผ่าน
	if isPassed {
		rewardRows, _ := tx.Query(ctx, `
			SELECT r.item_id, r.quantity, i.name 
			FROM public.receive r
			JOIN public.items i ON r.item_id = i.id
			WHERE r.quest_id = $1
		`, input.QuestID)

		type tempReward struct {
			ItemID int64
			Qty    int
			Name   string
		}
		var pendingRewards []tempReward

		hasOriginalRewards := false // เอาไว้เช็คว่าเควสนี้มีรางวัลไหม (สร้างจากตั๋วไหม)

		for rewardRows.Next() {
			var itemID int64
			var qty int
			var name string
			rewardRows.Scan(&itemID, &qty, &name)
			pendingRewards = append(pendingRewards, tempReward{ItemID: itemID, Qty: qty, Name: name})
			hasOriginalRewards = true
		}
		rewardRows.Close()

		// แจกรางวัลให้คนทำเควส
		for _, item := range pendingRewards {
			if item.ItemID == 22 || item.Name == "EXP" {
				tx.Exec(ctx, `UPDATE public.characters SET experience = experience + $1 WHERE user_id = $2`, item.Qty, userID)
			} else {
				tx.Exec(ctx, `
					INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
					VALUES ($1, $2, $3, NOW())
					ON CONFLICT (user_id, item_id) 
					DO UPDATE SET quantity = public.collect.quantity + EXCLUDED.quantity, acquired_date = NOW();
				`, userID, item.ItemID, item.Qty)
			}
			rewards = append(rewards, map[string]interface{}{"item_id": item.ItemID, "name": item.Name, "amount": item.Qty})
		}

		// 🌟 8. ตรวจสอบว่าสำเร็จ "100% ครบทุกคน" หรือไม่ (เพื่อแจกโบนัสทันที)
		if hasOriginalRewards {
			var ownerRewarded bool
			err := tx.QueryRow(ctx, `SELECT COALESCE(owner_rewarded, false) FROM public.quests WHERE id = $1`, input.QuestID).Scan(&ownerRewarded)
			
			if err == nil && !ownerRewarded {
				var totalMembers int
				tx.QueryRow(ctx, `SELECT COUNT(*) FROM public.user_profiles WHERE club_id = $1 AND club_role != 'owner'`, questClubID).Scan(&totalMembers)

				var completedMembers int
				tx.QueryRow(ctx, `SELECT COUNT(*) FROM public.do_quests WHERE quest_id = $1 AND status = 'completed'`, input.QuestID).Scan(&completedMembers)

				// 🌟 ถ้าสมาชิก (ไม่รวมหัวหน้า) ทำเสร็จครบ 100% ทุกคน!
				if totalMembers > 0 && completedMembers == totalMembers {
					
					// ล็อกสถานะว่าเคลียร์บิลแล้ว
					tx.Exec(ctx, `UPDATE public.quests SET owner_rewarded = true WHERE id = $1`, input.QuestID)

					// 8.1 เตรียมของรางวัลให้ "หัวหน้า" (รางวัลฐาน + เหรียญตามจำนวนคน + โบนัส 500)
					var ownerID uuid.UUID
					err = tx.QueryRow(ctx, `SELECT id FROM public.user_profiles WHERE club_id = $1 AND club_role = 'owner'`, questClubID).Scan(&ownerID)
					if err == nil {
						ownerRewardsMap := make(map[int64]int)
						for _, pr := range pendingRewards {
							ownerRewardsMap[pr.ItemID] += pr.Qty
						}
						ownerRewardsMap[20] += 10 * totalMembers // โบนัสพื้นฐาน
						ownerRewardsMap[20] += 500               // 🌟 โบนัส 100% สำหรับหัวหน้า

						sendRewardNotificationHelper(ctx, tx, ownerID, "🎉 ภารกิจชมรมสำเร็จ 100%!", 
							fmt.Sprintf("สุดยอด! สมาชิกทุกคนทำภารกิจ \"%s\" สำเร็จ! คุณได้รับรางวัลและโบนัสพิเศษ 500 เหรียญ", questName), 
							ownerRewardsMap)
					}

					// 8.2 เตรียมของรางวัลโบนัสให้ "ลูกน้องทุกคนที่ทำเสร็จ" (โบนัส 500)
					memberBonusMap := map[int64]int{20: 500}
					rowsMembers, _ := tx.Query(ctx, `SELECT user_id FROM public.do_quests WHERE quest_id = $1 AND status = 'completed'`, input.QuestID)
					var memberIDs []uuid.UUID
					for rowsMembers.Next() {
						var mID uuid.UUID
						rowsMembers.Scan(&mID)
						memberIDs = append(memberIDs, mID)
					}
					rowsMembers.Close()

					for _, mID := range memberIDs {
						sendRewardNotificationHelper(ctx, tx, mID, "🎁 โบนัสทีมเวิร์ค! ภารกิจสำเร็จ 100%", 
							fmt.Sprintf("ยอดเยี่ยมมาก! สมาชิกทุกคนทำภารกิจ \"%s\" สำเร็จ คุณได้รับโบนัส 500 เหรียญ!", questName), 
							memberBonusMap)
					}
				}
			}
		}
	}

	tx.Commit(ctx)

	go func(u uuid.UUID) {
		CheckCoinAchievement(context.Background(), u)
	}(userID)
	CheckLevelAchievement(ctx, userID)

	msg := "คะแนนไม่ถึงเกณฑ์ กรุณารอ 10 นาที"
	if isPassed {
		msg = "ภารกิจสำเร็จ!"
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"is_passed":     isPassed,
		"score":         score,
		"passing_score": passingScore,
		"rewards":       rewards,
		"message":       msg,
	})
}

// ------------------------------------------------------------------------
// API 4: แก้ไขภารกิจชมรม (Update Club Quest)
// ------------------------------------------------------------------------
// POST /clubs/quests/update
func UpdateClubQuest(c *gin.Context) {
	userIdVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userIDStr := fmt.Sprintf("%v", userIdVal)
	userID, _ := uuid.Parse(userIDStr)

	// รับค่าแบบ Multipart Form-Data
	questIDStr := c.PostForm("quest_id")
	name := c.PostForm("name")
	detail := c.PostForm("detail")
	dueDateStr := c.PostForm("due_date") // รับค่าวันหมดเขตใหม่
	passingScoreStr := c.PostForm("passing_score")
	questionsStr := c.PostForm("questions")
	deleteImageStr := c.PostForm("delete_image")

	if questIDStr == "" || name == "" || dueDateStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ข้อมูลไม่ครบถ้วน (ต้องการ quest_id, name, due_date)"})
		return
	}

	questID, err := strconv.ParseInt(questIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "quest_id ไม่ถูกต้อง"})
		return
	}

	// 🌟 แปลงวันที่
	dueDate, err := time.Parse(time.RFC3339, dueDateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "รูปแบบวันหมดเขต (due_date) ไม่ถูกต้อง"})
		return
	}

	passingScore := 0
	if passingScoreStr != "" {
		passingScore, _ = strconv.Atoi(passingScoreStr)
	}

	// 🌟 แปลงคำถาม (อนุญาตให้ไม่มีคำถามได้)
	var questions []QuestionInput
	if questionsStr != "" && questionsStr != "[]" {
		err = json.Unmarshal([]byte(questionsStr), &questions)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "รูปแบบคำถาม (questions) ไม่ถูกต้อง"})
			return
		}
		if len(questions) > 10 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "จำนวนคำถามต้องไม่เกิน 10 ข้อ"})
			return
		}
	}

	ctx := context.Background()
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction failed"})
		return
	}
	defer tx.Rollback(ctx)

	// 1. ตรวจสอบสิทธิ์ (ต้องเป็น Owner ของชมรม)
	var clubID int64
	var clubRole string
	err = tx.QueryRow(ctx, `SELECT club_id, club_role FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubID, &clubRole)
	if err != nil || clubID == 0 || clubRole != "owner" {
		c.JSON(http.StatusForbidden, gin.H{"error": "เฉพาะหัวหน้าชมรมเท่านั้นที่สามารถแก้ไขภารกิจได้"})
		return
	}

	// 2. ตรวจสอบว่าภารกิจนี้เป็นของชมรมนี้จริงๆ
	var existingQuestClubID int64
	err = tx.QueryRow(ctx, `SELECT club_id FROM public.quests WHERE id = $1 FOR UPDATE`, questID).Scan(&existingQuestClubID)
	if err != nil || existingQuestClubID != clubID {
		c.JSON(http.StatusForbidden, gin.H{"error": "ไม่พบภารกิจ หรือคุณไม่มีสิทธิ์แก้ไขภารกิจนี้"})
		return
	}

	// 3. จัดการอัปโหลดรูปภาพใหม่ไปยัง Cloudinary (ถ้ามี)
	var newImageUrl *string
	file, _, err := c.Request.FormFile("image")
	if err == nil {
		defer file.Close()
		cloudinaryURL := os.Getenv("CLOUDINARY_URL")
		if cloudinaryURL != "" {
			cld, _ := cloudinary.NewFromURL(cloudinaryURL)
			resp, err := cld.Upload.Upload(ctx, file, uploader.UploadParams{
				Folder: "KidzKanKlai/club_quests",
			})
			if err == nil {
				url := resp.SecureURL
				newImageUrl = &url
			}
		}
	}

	// 4. อัปเดตข้อมูลภารกิจ (รวมถึง due_date ใหม่)
	var detailPtr *string
	if detail != "" {
		detailPtr = &detail
	}

	if newImageUrl != nil {
		// กรณี: อัปโหลดรูปภาพใหม่
		updateQuestQuery := `UPDATE public.quests SET name = $1, detail = $2, image = $3, passing_score = $4, due_date = $5 WHERE id = $6`
		tx.Exec(ctx, updateQuestQuery, name, detailPtr, newImageUrl, passingScore, dueDate, questID)
	} else if deleteImageStr == "true" {
		// กรณี: กดลบรูปทิ้ง
		updateQuestQuery := `UPDATE public.quests SET name = $1, detail = $2, image = NULL, passing_score = $3, due_date = $4 WHERE id = $5`
		tx.Exec(ctx, updateQuestQuery, name, detailPtr, passingScore, dueDate, questID)
	} else {
		// กรณี: ไม่ได้แก้รูปภาพ (เก็บรูปเดิมไว้)
		updateQuestQuery := `UPDATE public.quests SET name = $1, detail = $2, passing_score = $3, due_date = $4 WHERE id = $5`
		tx.Exec(ctx, updateQuestQuery, name, detailPtr, passingScore, dueDate, questID)
	}

	// 5. ลบคำถามเก่าออกทั้งหมด แล้ว Insert ใหม่ (ง่ายและชัวร์สุด)
	tx.Exec(ctx, `DELETE FROM public.quest_questions WHERE quest_id = $1`, questID)

	// บันทึกคำถามชุดใหม่ (ถ้ามี)
	for _, q := range questions {
		insertQuestionQuery := `
			INSERT INTO public.quest_questions (quest_id, question_text, choice_a, choice_b, choice_c, choice_d, correct_answer)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`
		tx.Exec(ctx, insertQuestionQuery, questID, q.QuestionText, q.ChoiceA, q.ChoiceB, q.ChoiceC, q.ChoiceD, q.CorrectAnswer)
	}

	tx.Commit(ctx)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "แก้ไขภารกิจสำเร็จ!",
	})
}

// ProcessExpiredClubQuests - เรียกใช้ทุกครั้งเมื่อเข้า Lobby/Club เพื่อประเมินเควสชมรมที่หมดอายุ
func ProcessExpiredClubQuests(ctx context.Context, userID uuid.UUID) {
	// เช็คก่อนว่ามีคลับไหม
	var clubID int64
	err := configs.DB.QueryRow(ctx, `SELECT club_id FROM public.user_profiles WHERE id = $1`, userID).Scan(&clubID)
	if err != nil || clubID == 0 {
		return
	}

	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		return
	}
	defer tx.Rollback(ctx)

	// ล็อกระดับคลับ ป้องกันผู้เล่นหลายคนในคลับเดียวกันเข้าหน้า Lobby พร้อมกันแล้วเรียกซ้ำซ้อน
	_, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock(hashtext($1::text))", fmt.Sprintf("club_eval_%d", clubID))
	if err != nil {
		return
	}

	// หาเควสชมรมที่หมดเวลาแล้ว แต่ยังไม่ได้สรุปผลแจกรางวัล
	query := `
		SELECT id, name FROM public.quests 
		WHERE club_id = $1 AND due_date <= NOW() AND owner_rewarded = false AND type = 'ชมรม'
	`
	rows, err := tx.Query(ctx, query, clubID)
	if err != nil {
		return
	}

	type expiredQuest struct {
		ID   int64
		Name string
	}
	var quests []expiredQuest
	for rows.Next() {
		var q expiredQuest
		rows.Scan(&q.ID, &q.Name)
		quests = append(quests, q)
	}
	rows.Close()

	for _, q := range quests {
		// 1. นับจำนวนคน
		var totalMembers, completedMembers int
		tx.QueryRow(ctx, `SELECT COUNT(*) FROM public.user_profiles WHERE club_id = $1 AND club_role != 'owner'`, clubID).Scan(&totalMembers)
		tx.QueryRow(ctx, `SELECT COUNT(*) FROM public.do_quests WHERE quest_id = $1 AND status = 'completed'`, q.ID).Scan(&completedMembers)

		// 2. ปิดจ๊อบเควสนี้ (ไม่ว่าจะผ่านหรือไม่ผ่านเกณฑ์ ก็จะไม่กลับมาเช็คซ้ำ)
		tx.Exec(ctx, `UPDATE public.quests SET owner_rewarded = true WHERE id = $1`, q.ID)

		// 3. ถ้าสำเร็จตั้งแต่ 50% ขึ้นไป แจกรางวัลให้หัวหน้า
		if totalMembers > 0 && float64(completedMembers) >= float64(totalMembers)*0.5 {
			
			// เช็คว่าเควสนี้สร้างด้วยตั๋วไหม (มีตาราง receive ไหม)
			var hasRewards bool
			tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM public.receive WHERE quest_id = $1)`, q.ID).Scan(&hasRewards)

			if hasRewards {
				var ownerID uuid.UUID
				err = tx.QueryRow(ctx, `SELECT id FROM public.user_profiles WHERE club_id = $1 AND club_role = 'owner'`, clubID).Scan(&ownerID)
				
				if err == nil {
					ownerRewardsMap := make(map[int64]int)
					// ดึงของรางวัลตั้งต้น
					rRows, _ := tx.Query(ctx, `SELECT item_id, quantity FROM public.receive WHERE quest_id = $1`, q.ID)
					for rRows.Next() {
						var iID int64
						var qty int
						rRows.Scan(&iID, &qty)
						ownerRewardsMap[iID] += qty
					}
					rRows.Close()

					ownerRewardsMap[20] += 10 * totalMembers // บวกเหรียญโบนัสตามจำนวนคน

					// ถ้าเกิดกรณีที่ครบ 100% เป๊ะตอนวินาทีสุดท้ายที่หมดเวลาพอดี ก็แจกโบนัสให้หัวหน้าด้วย
					is100Percent := (completedMembers == totalMembers)
					if is100Percent {
						ownerRewardsMap[20] += 500
						sendRewardNotificationHelper(ctx, tx, ownerID, "🎉 ภารกิจชมรมหมดเวลา (สำเร็จ 100%)", 
							fmt.Sprintf("ยอดเยี่ยมมาก! ภารกิจ \"%s\" หมดเวลาและสมาชิกทุกคนทำสำเร็จ คุณได้รับโบนัส 500 เหรียญ!", q.Name), ownerRewardsMap)
						
						// แจก 500 ให้ลูกน้องด้วย
						memberBonusMap := map[int64]int{20: 500}
						mRows, _ := tx.Query(ctx, `SELECT user_id FROM public.do_quests WHERE quest_id = $1 AND status = 'completed'`, q.ID)
						for mRows.Next() {
							var mID uuid.UUID
							mRows.Scan(&mID)
							sendRewardNotificationHelper(ctx, tx, mID, "🎁 โบนัสทีมเวิร์ค! ภารกิจสำเร็จ 100%", 
								fmt.Sprintf("ภารกิจ \"%s\" หมดเวลาและทุกคนทำสำเร็จ! รับโบนัส 500 เหรียญ", q.Name), memberBonusMap)
						}
						mRows.Close()
					} else {
						// กรณีปกติ ทะลุ 50% แต่ไม่ถึง 100% (หัวหน้าได้คนเดียว)
						sendRewardNotificationHelper(ctx, tx, ownerID, "สรุปผลภารกิจชมรม (สำเร็จ > 50%) 🎉", 
							fmt.Sprintf("ภารกิจ \"%s\" หมดเวลาแล้ว สมาชิกช่วยกันทำสำเร็จเกินครึ่ง! เข้ามารับของรางวัลได้เลย", q.Name), ownerRewardsMap)
					}
				}
			}
		}
	}
	tx.Commit(ctx)
}

// Helper Function สำหรับสร้างจดหมายและยัดของรางวัล
func sendRewardNotificationHelper(ctx context.Context, tx pgx.Tx, userID uuid.UUID, title string, detail string, rewards map[int64]int) {
	var notifID int64
	notiType := "reward"
	imgUrl := "assets/images/icon/icon-gift.png"
	dueDate := time.Now().AddDate(0, 0, 7) // เก็บได้ 7 วัน

	err := tx.QueryRow(ctx, `
		INSERT INTO public.notifications (title, detail, type, image, start_date, due_date) 
		VALUES ($1, $2, $3, $4, NOW(), $5) RETURNING id
	`, title, detail, notiType, imgUrl, dueDate).Scan(&notifID)
	
	if err == nil && notifID > 0 {
		tx.Exec(ctx, `INSERT INTO public.get_notifications (user_id, notification_id, status, reward_claimed) VALUES ($1, $2, 'unread', false)`, userID, notifID)
		for itemID, qty := range rewards {
			tx.Exec(ctx, `INSERT INTO public.obtain (notification_id, item_id, quantity, reward_claimed) VALUES ($1, $2, $3, false)`, notifID, itemID, qty)
		}
	}
}