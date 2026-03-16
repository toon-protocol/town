// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Minimal ERC-20 + EIP-3009 for Anvil x402 demo testing.
 *
 * Storage layout MUST match the existing deployed mock ERC-20 at
 * 0x5FbDB2315678afecb367f032d93F642f64180aa3 so that `anvil_setCode`
 * can replace the runtime bytecode while preserving existing balances.
 *
 * Standard OpenZeppelin ERC-20 storage layout (slots 0-4):
 *   0: mapping(address => uint256) _balances
 *   1: mapping(address => mapping(address => uint256)) _allowances
 *   2: uint256 _totalSupply
 *   3: string _name
 *   4: string _symbol
 *
 * EIP-3009 adds slot 5 for nonce tracking (no conflict).
 */
contract MockUSDC_EIP3009 {
    // --- Storage (must match existing ERC-20 layout) ---
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    // New slot for EIP-3009 nonce tracking
    mapping(address => mapping(bytes32 => bool)) private _authorizationStates;

    // --- EIP-712 constants ---
    bytes32 private constant _DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TRANSFER_WITH_AUTH_TYPEHASH =
        keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");

    // --- Events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    // --- Standard ERC-20 ---

    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return 18; }
    function totalSupply() public view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view returns (uint256) { return _balances[account]; }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        unchecked { _allowances[from][msg.sender] = currentAllowance - amount; }
        _transfer(from, to, amount);
        return true;
    }

    // --- EIP-3009 ---

    function authorizationState(address authorizer, bytes32 nonce) public view returns (bool) {
        return _authorizationStates[authorizer][nonce];
    }

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp > validAfter, "Authorization not yet valid");
        require(block.timestamp < validBefore, "Authorization expired");
        require(!_authorizationStates[from][nonce], "Authorization already used");

        bytes32 structHash = keccak256(abi.encode(
            _TRANSFER_WITH_AUTH_TYPEHASH,
            from, to, value, validAfter, validBefore, nonce
        ));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            _domainSeparator(),
            structHash
        ));

        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0) && signer == from, "Invalid signature");

        _authorizationStates[from][nonce] = true;
        _transfer(from, to, value);

        emit AuthorizationUsed(from, nonce);
    }

    // --- Mint (for testing) ---

    function mint(address to, uint256 amount) external {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    // --- Internal ---

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero");
        require(to != address(0), "ERC20: transfer to zero");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: insufficient balance");
        unchecked { _balances[from] = fromBalance - amount; }
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            _DOMAIN_TYPEHASH,
            keccak256(bytes("USD Coin")),
            keccak256(bytes("2")),
            block.chainid,
            address(this)
        ));
    }
}
