package main

import (
	"backend/configs"
	"context"
	"fmt"
	"log"
)

func main() {
	configs.ConnectDB()
	ctx := context.Background()

	ids := []int64{25, 32, 38}
	rows, err := configs.DB.Query(ctx, "SELECT id, name, rarity FROM items WHERE id = ANY($1)", ids)
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	fmt.Println("ID | Name | Rarity")
	for rows.Next() {
		var id int64
		var name, rarity string
		if err := rows.Scan(&id, &name, &rarity); err != nil {
			log.Fatal(err)
		}
		fmt.Printf("%d | %s | %s\n", id, name, rarity)
	}
}
