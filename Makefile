BRANCH ?= $(shell git branch --show-current)
MSG ?= update

.PHONY: g s p

g:
	git pull --rebase origin $(BRANCH)
	git add .
	git commit -m "$(MSG)"
	git push -u origin $(BRANCH)

s:
	git status

p:
	git pull --rebase origin $(BRANCH)
