// Multiple PixelPimp MysteryBox Factory contract
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MysteryBox.sol";

contract MysteryBoxFactory is Ownable {
    using SafeMath for uint256;
    
    /** Create MysteryBox fee (BNB) */
	uint256 public creatingFee;	

    address[] public boxes;
	// collection address => creator address
	mapping(address => address) public boxCreators;

    /** Events */
    event MysteryBoxCreated(address box_address, address owner, string name, string uri, address paymentToken, uint256 price);
    event FeeUpdated(uint256 old_fee, uint256 new_fee);

    constructor () {		
		creatingFee = 0 ether;		
	}

    function createMysteryBox(string memory _name, 
		string memory _uri,
		address _tokenAddress,
		uint256 _price) external  payable {
		
		require(msg.value >= creatingFee, "insufficient fee");		

		bytes memory bytecode = type(MysteryBox).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_name, _tokenAddress, block.timestamp));
        address payable lootbox;
		assembly {
            lootbox := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        MysteryBox(lootbox).initialize(_name, _uri, _tokenAddress, _price, msg.sender);
		boxes.push(lootbox);
		boxCreators[lootbox] = msg.sender;

		emit MysteryBoxCreated(lootbox, msg.sender, _name, _uri, _tokenAddress, _price);
	}
    function updateCreatingFee(uint256 _fee) public onlyOwner {
        uint256 oldFee = creatingFee;
		creatingFee = _fee;
		emit FeeUpdated(oldFee, _fee);
    }

    function withdrawBNB() public onlyOwner {
		uint balance = address(this).balance;
		require(balance > 0, "insufficient balance");
		(bool result, ) = payable(msg.sender).call{value: balance}("");
        require(result, "Failed to withdraw");		
	}

	function withdrawToken(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
		uint balance = token.balanceOf(address(this));
		require(balance > 0, "insufficient balance");
		require(token.transfer(msg.sender, balance));			
	}

    receive() external payable {}
}
