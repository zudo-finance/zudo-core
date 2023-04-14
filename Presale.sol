// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/IERC20.sol";
import "./MerkleProof.sol";

contract Presale {

    // Verification
    bytes32 public privateMerkleRoot;

    // Address Configs
    address public owner;
    address public zudo;

    // Sale Details
    uint public saleAmount; // 2,100,000
    uint public privateSaleRatio; // 500 / 1000
    uint public publicPrice; // 12000 zudos per eth
    uint public privatePrice; // 13000 zudos per eth
    uint public maxDeposit; // 10 eth

    // Sale Progress
    uint public publicSold;
    uint public privateSold;

    // Sale Stages
    bool public isPublicStart;
    bool public isPrivateStart;
    bool public isClaimStart;

    mapping(address => uint) public alloc;
    mapping(address => uint) public committedPublic;
    mapping(address => uint) public committedPrivate;

    constructor(
        address _zudo,
        uint _publicPrice,
        uint _privatePrice,
        uint _saleAmount,
        uint _maxDeposit,
        uint _privateSaleRatio,
        bytes32 _privateMerkleRoot
    ) {
        owner = msg.sender;
        zudo = _zudo;
        publicPrice = _publicPrice;
        privatePrice = _privatePrice;
        saleAmount = _saleAmount;
        maxDeposit = _maxDeposit;
        privateSaleRatio = _privateSaleRatio;
        privateMerkleRoot = _privateMerkleRoot;
    }

    function depositPrivate(
        bytes32[] calldata _merkleProof
    ) public payable {

        uint depositAmt = msg.value;

        require(depositAmt > 0, "Amount cannot be zero");
        require(isPrivateStart == true, "Private Sale is not available");
        require(
            committedPrivate[msg.sender] + depositAmt <= maxDeposit,
            "Max alloc reached"
        );

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, privateMerkleRoot, leaf),
            "Invalid address"
        );

        uint tokenAmt = depositAmt * privatePrice;

        require(saleAmount * privateSaleRatio / 1000 >= tokenAmt + privateSold, "Insufficient token balance");

        committedPrivate[msg.sender] += depositAmt;

        // Update Alloc
        alloc[msg.sender] += tokenAmt;

        privateSold += tokenAmt;
    }

    function depositPublic() public payable {

        uint depositAmt = msg.value;

        require(msg.value > 0, "Amount cannot be zero");
        require(isPublicStart == true, "Public Sale is not available");

        uint tokenAmt = depositAmt * publicPrice;

        if (isPrivateStart) {
            require(saleAmount * (1000 - privateSaleRatio) / 1000 >= tokenAmt + publicSold, "Insufficient token balance");
        } else {
            require(saleAmount >= tokenAmt + publicSold + publicSold, "Insufficient token balance");
        }

        committedPublic[msg.sender] += depositAmt;

        // Update Alloc
        alloc[msg.sender] += tokenAmt;

        publicSold += tokenAmt;
    }

    function claim() public {
        require(isClaimStart == true, "Claim not allowed");
        require(alloc[msg.sender] > 0, "Nothing to claim");
        IERC20(zudo).transfer(msg.sender, alloc[msg.sender]);
        alloc[msg.sender] = 0;
    }

    function startSale() public onlyOwner {
        isPublicStart = true;
        isPrivateStart = true;
    }

    function endPrivateSale() public onlyOwner {
        isPrivateStart = false;
    }

    function endPublicSale() public onlyOwner {
        isPublicStart = false;

        // transfer funds to owner for adding LP
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function startClaim() public onlyOwner {
        require(isPublicStart == false, "Presale is open");
        isClaimStart = true;
    }

    function recover() public onlyOwner {
        require(isClaimStart == true, "Claim is not allowed");
        uint unsoldAmt = saleAmount - privateSold - publicSold;
        IERC20(zudo).transfer(owner, unsoldAmt);
    }

    function setOwner(address _address) public onlyOwner {
        owner = _address;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
}