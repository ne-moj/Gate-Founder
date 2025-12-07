function interactionPossible(playerIndex, option)
	return true
end

function getInteractionText(playerIndex)
	return "Поздороваться"
end

function onInteractStart(playerIndex)
	Player(playerIndex):sendChatMessage(
		"Станция",
		0,
		"Привет, капитан! Добро пожаловать."
	)
end
