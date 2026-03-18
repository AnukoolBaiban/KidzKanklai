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
				Content: "คุณตอบได้เพียง 1 ประโยคเท่านั้น ห้ามมีประโยคที่สอง ห้ามอธิบาย ห้ามใส่เครื่องหมายคำพูด",
			},
			{
				Role:    "user",
				Content: "สร้างคำทักทายภาษาไทยสั้นๆ สำหรับตัวละครในเกมเด็ก ให้สนุกสนานและน่ารัก",
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
