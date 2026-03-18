package handlers

import (
	"backend/service"
	"net/http"

	"github.com/gin-gonic/gin"
)

// GenerateDialogue godoc
// POST /ai/dialogue
// ไม่ต้องส่ง Body — AI จะสุ่มคำทักทายสั้นๆ ภาษาไทยมาให้เลย
func GenerateDialogue(c *gin.Context) {
	greeting, err := service.GenerateGreeting()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "AI generation failed: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"dialogue": greeting})
}
