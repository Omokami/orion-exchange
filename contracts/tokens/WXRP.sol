pragma solidity 0.5.10;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WXRP is ERC20Detailed, ERC20 {
    constructor() public ERC20Detailed("Wrapped Ripple", "WXRP", 8) {
        _mint(msg.sender, 100e6 * 10**8);
    }
}
