extends Node
## Autoload: the player's banked money. Never at risk — untouched by a lost
## run (CONTEXT.md "Wallet"; spec §1).

signal money_changed(money: int)

var money: int = 0


func add(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)


func try_spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true
