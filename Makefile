-include .env

.PHONY: all test clean deploy help uninstall install snapshot format anvil 

all: clean uninstall install update build

# ---------- anvil constants ----------
PRIVATE_KEY_ANVIL_0 := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ADDRESS_ANVIL_0 := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PRIVATE_KEY_ANVIL_1 := 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
ADDRESS_ANVIL_1 := 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
RPC_URL_ANVIL := http://localhost:8545

# ---------- dependencies ----------
uninstall :; rm -rf dependencies/ && rm -rf soldeer.lock
install :; forge soldeer install
update:; forge soldeer update

# ---------- build ----------
build :; forge build
build-zksync :; forge build --zksync --system-mode=true
clean :; forge clean && rm -rf cache/

# ---------- tests ----------
TEST := forge test -vvv
TEST_ETHEREUM := $(TEST) --match-path "test/ethereum/*.t.sol"
# system-mode is used to interact with ZkSync system contracts
TEST_ZKSYNC := $(TEST) --match-path "test/zksync/*.t.sol" --zksync --system-mode=true

test :; $(TEST_ETHEREUM)
test-zksync :; $(TEST_ZKSYNC)
test-fork-sepolia :; $(TEST_ETHEREUM) --fork-url $(RPC_URL_SEPOLIA)
test-fork-mainnet :; $(TEST_ETHEREUM) --fork-url $(RPC_URL_MAINNET)

# ---------- coverage ----------
coverage :; forge coverage --no-match-test zksync --no-match-coverage "^(test|script|zksync)/"
coverage-lcov :; make coverage EXTRA_FLAGS="--report lcov"
coverage-txt :; make coverage EXTRA_FLAGS="--report debug > coverage.txt"

# ---------- static analysis ----------
format-check :; forge fmt --check
slither-install :; python3 -m pip install slither-analyzer
slither-upgrade :; python3 -m pip install --upgrade slither-analyzer
slither :; slither . --config-file slither.config.json --checklist

# ---------- etherscan ----------
check-etherscan-api:
	@response_mainnet=$$(curl -s "https://api.etherscan.io/api?module=account&action=balance&address=$(ADDRESS_DEV)&tag=latest&apikey=$(ETHERSCAN_API_KEY)"); \
	echo "Mainnet:" $$response_mainnet; \
	response_sepolia=$$(curl -s "https://api-sepolia.etherscan.io/api?module=account&action=balance&address=$(ADDRESS_DEV)&tag=latest&apikey=$(ETHERSCAN_API_KEY)"); \
	echo "Sepolia:" $$response_sepolia;

# ---------- deploy & interact ----------
ACCOUNT_ARGS := --account $(ACCOUNT_DEV) --sender $(ADDRESS_DEV)
VERIFY_ARGS := --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
ARGS_ANVIL := --rpc-url $(RPC_URL_ANVIL) --private-key $(PRIVATE_KEY_ANVIL_0)
ARGS_SEPOLIA := --rpc-url $(RPC_URL_SEPOLIA) $(ACCOUNT_ARGS)
ARGS_ARBITRUM := --rpc-url $(RPC_URL_ARBITRUM) $(ACCOUNT_ARGS)

DEPLOY := forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount --broadcast -vvvv
SEND_PACKED_USER_OP := forge script script/SendPackedUserOp.s.sol --broadcast -vvvv

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy :; $(DEPLOY) $(ARGS_ANVIL)
deploy-sepolia :; $(DEPLOY) $(ARGS_SEPOLIA) $(VERIFY_ARGS)
deploy-arbitrum :; $(DEPLOY) $(ARGS_ARBITRUM) $(VERIFY_ARGS)
sendPackedUserOp-arbitrum :; $(SEND_PACKED_USER_OP) $(ARGS_ARBITRUM)
