package handlers

import (
	"backend/configs"
	"context"
	"math/rand"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// Config
const CostPerPull = 2000
const CoinItemID = 20

// Gacha Pool Items
var GachaPool = []int64{24, 26, 33, 34, 35, 37, 39, 40}

// Duplicate Rewards mapping
var DuplicateRewards = map[string]int{
	"COMMON": 200,
	"RARE":   600,
	"EPIC":   1200,
}

// Gacha probabilities
const (
	WeightCommon = 90
	WeightRare   = 9
	WeightEpic   = 1
)

type GachaResponse struct {
	Item        map[string]interface{} `json:"item"`
	IsDuplicate bool                   `json:"is_duplicate"`
	CoinReward  int                    `json:"coin_reward"`
	Remaining   int                    `json:"remaining_coins"`
}

func PullGacha(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	ctx := context.Background()

	// 1. Get User's Coin Balance
	var currentCoins int
	err := configs.DB.QueryRow(ctx, `
		SELECT quantity FROM public.collect 
		WHERE user_id = $1 AND item_id = $2
	`, userID, CoinItemID).Scan(&currentCoins)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ไม่พบข้อมูลเหรียญ หรือเหรียญไม่พอ"})
		return
	}

	if currentCoins < CostPerPull {
		c.JSON(http.StatusBadRequest, gin.H{"error": "เหรียญไม่พอสำหรับการสุ่ม (ต้องการ 2,000 เหรียญ)"})
		return
	}

	// 2. Select an Item ID from the pool based on rarity
	// We'll fetch the rarities of our pool items first
	rows, err := configs.DB.Query(ctx, `
		SELECT id, name, description, image, rarity, category_id 
		FROM public.items 
		WHERE id = ANY($1)
	`, GachaPool)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch gacha pool"})
		return
	}
	defer rows.Close()

	type poolItem struct {
		ID          int64
		Name        string
		Description *string
		Image       *string
		Rarity      *string
		CategoryID  *int64
	}

	var commonItems, rareItems, epicItems []poolItem

	for rows.Next() {
		var i poolItem
		if err := rows.Scan(&i.ID, &i.Name, &i.Description, &i.Image, &i.Rarity, &i.CategoryID); err != nil {
			continue
		}
		if i.Rarity == nil {
			continue
		}
		switch *i.Rarity {
		case "COMMON":
			commonItems = append(commonItems, i)
		case "RARE":
			rareItems = append(rareItems, i)
		case "EPIC":
			epicItems = append(epicItems, i)
		}
	}

	// Determine Rarity to pull
	rand.Seed(time.Now().UnixNano())
	roll := rand.Intn(100) // 0-99

	var selectedPool []poolItem
	if roll < WeightCommon {
		selectedPool = commonItems
	} else if roll < WeightCommon+WeightRare {
		selectedPool = rareItems
	} else {
		selectedPool = epicItems
	}

	// Fallback if empty (should not happen if seed data is correct)
	if len(selectedPool) == 0 {
		if len(commonItems) > 0 {
			selectedPool = commonItems
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Gacha pool is empty"})
			return
		}
	}

	// Randomly pick one item from the selected rarity pool
	pulledItem := selectedPool[rand.Intn(len(selectedPool))]

	// 3. Begin Transaction to deduct coins and add item
	tx, err := configs.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// Deduct 2000 coins
	newCoins := currentCoins - CostPerPull
	_, err = tx.Exec(ctx, `
		UPDATE public.collect 
		SET quantity = quantity - $1 
		WHERE user_id = $2 AND item_id = $3
	`, CostPerPull, userID, CoinItemID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to deduct coins"})
		return
	}

	// 4. Check if user already owns the pulled item
	var ownedQuantity int
	err = tx.QueryRow(ctx, `
		SELECT quantity FROM public.collect 
		WHERE user_id = $1 AND item_id = $2
	`, userID, pulledItem.ID).Scan(&ownedQuantity)

	isDuplicate := err == nil && ownedQuantity > 0
	coinReward := 0

	if isDuplicate {
		// Calculate compensation based on Rarity
		rarityKey := "COMMON"
		if pulledItem.Rarity != nil {
			rarityKey = *pulledItem.Rarity
		}
		if val, ok := DuplicateRewards[rarityKey]; ok {
			coinReward = val
		}

		// Add compensated coins
		_, err = tx.Exec(ctx, `
			UPDATE public.collect 
			SET quantity = quantity + $1 
			WHERE user_id = $2 AND item_id = $3
		`, coinReward, userID, CoinItemID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add compensation coins"})
			return
		}
		newCoins += coinReward
	} else {
		// Insert new item
		_, err = tx.Exec(ctx, `
			INSERT INTO public.collect (user_id, item_id, quantity, acquired_date)
			VALUES ($1, $2, 1, NOW())
			ON CONFLICT (user_id, item_id) 
			DO UPDATE SET quantity = collect.quantity + 1
		`, userID, pulledItem.ID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add item to inventory"})
			return
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Transaction commit failed"})
		return
	}

	// Build Response
	res := GachaResponse{
		Item: map[string]interface{}{
			"id":          pulledItem.ID,
			"name":        pulledItem.Name,
			"description": pulledItem.Description,
			"image":       pulledItem.Image,
			"rarity":      pulledItem.Rarity,
			"category_id": pulledItem.CategoryID,
		},
		IsDuplicate: isDuplicate,
		CoinReward:  coinReward,
		Remaining:   newCoins,
	}

	c.JSON(http.StatusOK, res)
}
