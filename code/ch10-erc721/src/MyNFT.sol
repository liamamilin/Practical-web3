// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC165, IERC721, IERC721Metadata, IERC721Receiver} from "./IERC721.sol";

/// @title MyNFT —— 从零手写的 ERC-721（教学版，零外部依赖）
/// @notice 实现 ERC-721 核心 + Metadata + ERC-165；设计理由见本书第 10 章。
contract MyNFT is IERC721, IERC721Metadata {
    string public constant name = "Chapter10 NFT";
    string public constant symbol = "C10N";

    // 铸币权限持有者（演示 modifier 的典型用法；真实项目通常换成多签/治理）
    address public immutable owner;

    uint256 private _nextTokenId;

    // ---- 核心状态：四张表 ----
    // tokenId 是全局唯一主键，一切状态都挂在它上面
    mapping(uint256 tokenId => address) private _owners;
    mapping(address ownerAccount => uint256) private _balances;
    mapping(uint256 tokenId => address) private _tokenApprovals; // 单枚授权
    mapping(address ownerAccount => mapping(address operator => bool)) private _operatorApprovals; // 全量授权

    // ---- 自定义错误 ----
    error NotTokenOwner(address caller, address actualOwner);
    error NotApproved(address caller, uint256 tokenId);
    error NonexistentToken(uint256 tokenId);
    error TokenAlreadyMinted(uint256 tokenId);
    error ZeroAddress();
    error TransferToNonReceiver(address to);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotTokenOwner(msg.sender, owner);
        _; // 被修饰函数的函数体插在这一行
    }

    constructor() {
        owner = msg.sender;
    }

    // ---- 铸造（标准未规定，每个 NFT 自定规则；这里仅限部署者）----

    function mint(address to, uint256 tokenId) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != address(0)) revert TokenAlreadyMinted(tokenId);
        _owners[tokenId] = to;
        _balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        // ownerOf 同时完成"存在性检查"
        ownerOf(tokenId);
        return string.concat("https://example.com/metadata/", _toString(tokenId), ".json");
    }

    // ---- 只读层 ----

    function balanceOf(address ownerAccount) external view returns (uint256) {
        if (ownerAccount == address(0)) revert ZeroAddress();
        return _balances[ownerAccount];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        if (tokenOwner == address(0)) revert NonexistentToken(tokenId);
        return tokenOwner;
    }

    // ---- 转账 ----

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) revert ZeroAddress();

        // checks：存在、归属、调用者有权限
        address tokenOwner = ownerOf(tokenId);
        if (tokenOwner != from) revert NotTokenOwner(from, tokenOwner);
        if (msg.sender != tokenOwner && !_isApprovedOrOperator(tokenOwner, msg.sender, tokenId)) {
            revert NotApproved(msg.sender, tokenId);
        }

        // effects：改状态。转移前先清掉旧授权，防止"跟着 tokenId 走"的幽灵授权
        delete _tokenApprovals[tokenId];
        _balances[tokenOwner] -= 1;
        _owners[tokenId] = to;
        _balances[to] += 1;

        // 本函数无外部调用，交互层为空
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
    {
        transferFrom(from, to, tokenId);
        // interactions：接收方是合约时，先问它"会妥善保管 NFT 吗"
        if (to.code.length > 0) {
            (bool ok, bytes memory ret) = to.call(
                abi.encodeWithSelector(
                    IERC721Receiver.onERC721Received.selector, msg.sender, from, tokenId, data
                )
            );
            if (
                !ok || ret.length != 32
                    || abi.decode(ret, (bytes4)) != IERC721Receiver.onERC721Received.selector
            ) {
                revert TransferToNonReceiver(to);
            }
        }
    }

    // ---- 两层授权 ----

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (msg.sender != tokenOwner && !_operatorApprovals[tokenOwner][msg.sender]) {
            revert NotApproved(msg.sender, tokenId);
        }
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (operator == address(0)) revert ZeroAddress();
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        ownerOf(tokenId); // 先确认 tokenId 存在
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address ownerAccount, address operator) external view returns (bool) {
        return _operatorApprovals[ownerAccount][operator];
    }

    // ---- ERC-165：接口发现 ----

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId // 0x01ffc9a7
            || interfaceId == type(IERC721).interfaceId // 0x80ac58cd
            || interfaceId == type(IERC721Metadata).interfaceId; // 0x5b5e139f
    }

    // ---- 内部 ----

    function _isApprovedOrOperator(address tokenOwner, address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        return spender == _tokenApprovals[tokenId] || _operatorApprovals[tokenOwner][spender];
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 digits;
        for (uint256 temp = value; temp != 0; temp /= 10) {
            digits++;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
