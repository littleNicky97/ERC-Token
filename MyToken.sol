// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CitadelToken is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    mapping(address => bool) public minters;
    mapping(address => uint256) public lastMinted;
    mapping(address => uint256) public dailyMintedAmount;
    mapping(address => uint256) public minterCaps;
    mapping(uint256 => uint256) public dailyBurnedAmount;

    uint256 public constant TAX_PERCENT = 10; // 0.1% tax
    uint256 public constant BURN_PERCENT = 50; // 50% of the tax is burned

    address public treasuryAddress;

    constructor() ERC20("test Token", "MTK") {
        _mint(msg.sender, 50000000 * 10**decimals());
        minters[msg.sender] = true;
        minterCaps[msg.sender] = 100000 * 10**decimals();
        treasuryAddress = msg.sender; // Set the treasury address to the contract creator initially
    }

    function addMinter(address _minter, uint256 _cap) public onlyOwner {
        require(_minter != address(0), "Invalid minter address");
        minters[_minter] = true;
        minterCaps[_minter] = _cap;
    }

    function removeMinter(address _minter) public onlyOwner {
        minters[_minter] = false;
    }

    function mint(address _to, uint256 _amount) public nonReentrant {
        require(minters[msg.sender], "You must be a minter to mint tokens");
        require(_to != address(0), "Invalid recipient address");

        uint256 mintedToday = dailyMintedAmount[msg.sender];
        uint256 newMintedToday = mintedToday.add(_amount);

        if (block.timestamp > lastMinted[msg.sender].add(1 days)) {
            dailyMintedAmount[msg.sender] = 0;
        }

        require(newMintedToday <= minterCaps[msg.sender], "Exceeded daily minting cap");

        dailyMintedAmount[msg.sender] = newMintedToday;
        lastMinted[msg.sender] = block.timestamp;
        _mint(_to, _amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20) {
        super._mint(account, amount);
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        require(_treasuryAddress != address(0), "Invalid treasury address");
        treasuryAddress = _treasuryAddress;
    }

    function externalBurn(uint256 burnAmount) external {
        uint256 dayNumber = block.timestamp.div(1 days);
        if (block.timestamp > dayNumber.mul(1 days)) {
            dailyBurnedAmount[dayNumber] = 0;
        }
        dailyBurnedAmount[dayNumber] = dailyBurnedAmount[dayNumber].add(burnAmount);
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        uint256 tax = amount.mul(TAX_PERCENT).div(10000); // Calculate the tax
        uint256 burnAmount = tax.mul(BURN_PERCENT).div(100); // Calculate the burn amount
        uint256 treasuryAmount = tax.sub(burnAmount); // Calculate the amount sent to the treasury
        uint256 sendAmount = amount.sub(tax);

        uint256 dayNumber = block.timestamp.div(1 days);
        if (block.timestamp > dayNumber.mul(1 days)) {
            dailyBurnedAmount[dayNumber] = 0;
        }
        dailyBurnedAmount[dayNumber] = dailyBurnedAmount[dayNumber].add(burnAmount);

        super._transfer(sender, recipient, sendAmount);
        super._burn(sender, burnAmount); // Burn the calculated burn amount
        super._transfer(sender, treasuryAddress, treasuryAmount); // Send the treasury amount to the treasury address
    }   

}


