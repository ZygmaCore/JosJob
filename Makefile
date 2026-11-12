.DEFAULT_GOAL := help

BRANCH ?= $(shell git branch --show-current)
MSG ?= update

.PHONY: g s p

g:
	@git add .
	@git commit -m "$(MSG)"
	@git pull --rebase origin $(BRANCH)
	@git push -u origin $(BRANCH)

s:
	@git status

p:
	@git pull --rebase origin $(BRANCH)
