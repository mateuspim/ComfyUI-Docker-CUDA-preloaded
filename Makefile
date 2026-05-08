.PHONY: up down build rebuild restart logs shell clean check-urls

# Pre-create bind-mount dirs so Docker doesn't create them as root
_dirs:
	@mkdir -p models custom_nodes/.last_commits output input workflows

up: _dirs
	docker compose up

up-detached: _dirs
	docker compose up -d

down:
	docker compose down

build: _dirs
	docker compose up --build

rebuild: down
	docker compose up --build

restart:
	docker compose restart

logs:
	docker compose logs -f

shell:
	docker exec -it comfyui bash

clean:
	docker compose down
	docker volume rm comfyui_venv
	rm -rf custom_nodes/.last_commits

check-urls:
	./check_urls.sh
