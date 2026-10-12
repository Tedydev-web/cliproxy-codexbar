.PHONY: all backend client clean

all:
	@echo "Sử dụng:"
	@echo "  make backend  - Cài đặt daemon service trên Linux"
	@echo "  make client   - Biên dịch và cài đặt trên macOS"

backend:
	cd backend && ./setup-backend.sh

client:
	cd client-macos && ./install-client.sh

clean:
	rm -rf client-macos/build
