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

// GetGachaRates returns all gacha pool items with their computed drop rates
func GetGachaRates(c *gin.Context) {
	ctx := context.Background()

	rows, err := configs.DB.Query(ctx, `
		SELECT id, name, description, image, rarity, category_id 
		FROM public.items 
		WHERE id = ANY($1)
		ORDER BY rarity DESC, id ASC
	`, GachaPool)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch gacha rates"})
		return
	}
	defer rows.Close()

	type RateItem struct {
		ID          int64   `json:"id"`
		Name        string  `json:"name"`
		Description string  `json:"description"`
		Image       string  `json:"image"`
		Rarity      string  `json:"rarity"`
		CategoryID  int64   `json:"category_id"`
		Rate        float64 `json:"rate"`
	}

	var commonItems, rareItems, epicItems []RateItem

	for rows.Next() {
		var (
			id         int64
			name       string
			desc       *string
			image      *string
			rarity     *string
			categoryID *int64
		)
		if err := rows.Scan(&id, &name, &desc, &image, &rarity, &categoryID); err != nil {
			continue
		}
		item := RateItem{
			ID:          id,
			Name:        name,
			Description: func() string { if desc != nil { return *desc }; return name }(),
			Image:       func() string { if image != nil { return *image }; return "" }(),
			Rarity:      func() string { if rarity != nil { return *rarity }; return "COMMON" }(),
			CategoryID:  func() int64 { if categoryID != nil { return *categoryID }; return 0 }(),
		}
		switch item.Rarity {
		case "EPIC":
			epicItems = append(epicItems, item)
		case "RARE":
			rareItems = append(rareItems, item)
		default:
			commonItems = append(commonItems, item)
		}
	}

	// Compute per-item rates based on rarity weights
	var result []RateItem
	if len(epicItems) > 0 {
		rateEach := float64(WeightEpic) / float64(len(epicItems))
		for _, it := range epicItems {
			it.Rate = rateEach
			result = append(result, it)
		}
	}
	if len(rareItems) > 0 {
		rateEach := float64(WeightRare) / float64(len(rareItems))
		for _, it := range rareItems {
			it.Rate = rateEach
			result = append(result, it)
		}
	}
	if len(commonItems) > 0 {
		rateEach := float64(WeightCommon) / float64(len(commonItems))
		for _, it := range commonItems {
			it.Rate = rateEach
			result = append(result, it)
		}
	}

	c.JSON(http.StatusOK, gin.H{"items": result})
}
