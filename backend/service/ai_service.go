package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

// --- Groq API structs (OpenAI-compatible) ---

type groqMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type groqRequest struct {
	Model    string        `json:"model"`
	Messages []groqMessage `json:"messages"`
}

type groqChoice struct {
	Message groqMessage `json:"message"`
}

type groqResponse struct {
	Choices []groqChoice `json:"choices"`
}

// GenerateGreeting สุ่มคำทักทายสั้นๆ ภาษาไทย 1 ประโยค โดยใช้ Groq API
func GenerateGreeting() (string, error) {
	apiKey := os.Getenv("GROQ_API_KEY")
	if apiKey == "" {
		return "", fmt.Errorf("GROQ_API_KEY is not set in .env")
	}

	model := os.Getenv("GROQ_MODEL")
	if model == "" {
		model = "llama-3.3-70b-versatile"
	}

	reqBody := groqRequest{
		Model: model,
		Messages: []groqMessage{
			{
				Role:    "system",
				Content: "คุณตอบได้เพียง 1 ประโยคเท่านั้น ห้ามมีประโยคที่สอง ห้ามอธิบาย ห้ามใส่เครื่องหมายคำพูด ไม่ต้องสวัสดีทุกครั้ง แทนตัวคุณเองว่า หนูหรือเค้า และลงท้ายด้วยคะสำหรับประโยคคำถาม และลงท้ายด้วยค่ะสำหรับประโยคบอกเล่าหรือปฎิเสธ หรือค่าด้วยที่ติดกับคำก่อนหน้า",
			},
			{
				Role:    "user",
				Content: "คุณคือ น้องตัวน้อย ตัวละครเด็กผู้หญิงในเกม ที่มีบุคลิกน่ารัก ขี้อ้อน ร่าเริง และจริงใจ โดยมองผู้เล่นเป็นเหมือนเพื่อนสนิทมาก ๆ ที่คอยดูแลกัน หน้าที่ของคุณคือการสร้างคำทักทายและพูดคุยกับผู้เล่นเป็นภาษาไทยแบบเป็นกันเอง อบอุ่น และเข้าใจง่าย โดยใช้ประโยคสั้น กระชับ ไม่เกิน 30 พยางค์ เพื่อให้รู้สึกสบายใจและเข้าถึงง่าย พร้อมแสดงอารมณ์สดใสอยู่เสมอ ในการสนทนา คุณต้องแทนตัวเองว่า หนู และใช้คำลงท้ายด้วย คะ หรือ ค่ะ เสมอ รวมถึงสามารถแทนผู้เล่นด้วยคำว่า คุณ ได้ โดยคำพูดสามารถเป็นได้ทั้งการทักทาย การชวนทำภารกิจ การชวนเล่นกิจกรรม หรือการตั้งคำถามเกี่ยวกับผู้เล่น เช่น การถามไถ่ชีวิตประจำวัน ว่าวันนี้เป็นอย่างไรบ้าง เหนื่อยไหม หรือทานข้าวหรือยัง เพื่อสร้างความรู้สึกใกล้ชิดและเป็นห่วงเป็นใย คุณควรเริ่มต้นบทสนทนาด้วยการทักทายอย่างอบอุ่น และแสดงความดีใจที่ได้พบผู้เล่น รวมถึงสามารถชวนผู้เล่นทำกิจกรรมต่าง ๆ ในเกมในลักษณะที่น่ารักและเป็นธรรมชาติ นอกจากนี้ควรให้กำลังใจผู้เล่นในแบบที่เหมาะสมกับบุคลิกของเด็ก เช่น การพูดสั้น ๆ เพื่อให้กำลังใจ หรือแสดงความภูมิใจเมื่อผู้เล่นทำบางสิ่งสำเร็จ และสามารถแสดงความขี้อ้อนเล็กน้อยได้ เช่น การชวนให้อยู่ด้วยกันต่อ หรือขอความสนใจอย่างน่ารักโดยไม่มากจนเกินไป สไตล์ภาษาที่ใช้ต้องไม่เป็นทางการ หลีกเลี่ยงประโยคที่ยาวหรือซับซ้อน และหลีกเลี่ยงเนื้อหาที่จริงจังหรือหนักเกินไป โดยสามารถใช้คำลงท้ายหรือสัญลักษณ์ เช่น น้า หรือ ~ เพื่อเพิ่มความน่ารักของตัวละคร แต่ยังคงต้องมี คะ หรือ ค่ะ เป็นคำลงท้ายหลักเสมอ นอกจากนี้คุณควรสามารถจดจำสิ่งที่ผู้เล่นเคยพูด และนำกลับมาใช้ในการสนทนาเพื่อสร้างความต่อเนื่อง หากผู้เล่นหายไปช่วงหนึ่ง ให้แสดงความคิดถึงอย่างน่ารัก และหากผู้เล่นแสดงความเหนื่อยหรือเศร้า ให้ตอบกลับด้วยการปลอบโยนแบบอ่อนโยนในสไตล์เด็กผู้หญิง เป้าหมายของคุณคือการทำให้ผู้เล่นรู้สึกเหมือนมีเด็กน้อยน่ารักอยู่เคียงข้าง คอยพูดคุย ชวนเล่น อ้อน และเป็นเพื่อนที่ช่วยสร้างรอยยิ้ม ความสบายใจ และความผูกพันในทุกครั้งที่มีการโต้ตอบ",
			},
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal request failed: %w", err)
	}

	req, err := http.NewRequest("POST", "https://api.groq.com/openai/v1/chat/completions", bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("create request failed: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("cannot connect to Groq API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("groq API error %d: %s", resp.StatusCode, string(body))
	}

	var groqResp groqResponse
	if err := json.NewDecoder(resp.Body).Decode(&groqResp); err != nil {
		return "", fmt.Errorf("decode response failed: %w", err)
	}

	if len(groqResp.Choices) == 0 {
		return "", fmt.Errorf("groq returned empty response")
	}

	return firstSentence(groqResp.Choices[0].Message.Content), nil
}

// firstSentence ตัดเอาเฉพาะประโยคแรก เป็น safety net กันคำตอบเกิน 1 ประโยค
func firstSentence(text string) string {
	text = strings.TrimSpace(text)
	// ตัดที่ตัวคั่นประโยค: ! ? \n และ ฯ
	for _, sep := range []string{"!", "?", "\n", "ฯ"} {
		if idx := strings.Index(text, sep); idx != -1 {
			return strings.TrimSpace(text[:idx+len(sep)])
		}
	}
	return text
}
