dev:            ## Build & run the full stack
	docker compose up --build -d
	@echo "web:      http://localhost:3000"
	@echo "identity: http://localhost:8081/actuator/health"
	@echo "family:   http://localhost:8082/actuator/health"
logs:
	docker compose logs -f
down:
	docker compose down
e2e:            ## Run the golden journey against the running stack
	cd ../fs-e2e && ./smoke.sh && cd ../fs-web && npx playwright test
