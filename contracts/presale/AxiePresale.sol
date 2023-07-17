// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/Pausable.sol";
import "./SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AxiePresale is Ownable, Pausable {
    using SafeMath for uint256;

    // No Axies can be adopted after this end date: Friday, March 16, 2018 11:59:59 PM GMT.
    uint256 public constant PRESALE_END_TIMESTAMP = 1699493300;

    uint8 public constant CLASS_BEAST = 0;
    uint8 public constant CLASS_AQUATIC = 2;
    uint8 public constant CLASS_PLANT = 4;

    uint256 public INITIAL_PRICE_INCREMENT = 0.000016 ether;
    uint256 public a;

    uint256 public INITIAL_PRICE = INITIAL_PRICE_INCREMENT;
    uint256 public REF_CREDITS_PER_AXIE = 5;

    mapping(uint8 => uint256) public currentPrices;
    mapping(uint8 => uint256) public priceIncrements;

    mapping(uint8 => uint256) public totalAxiesAdopted;
    mapping(address => mapping(uint8 => uint256)) public axiesAdopted;

    mapping(address => uint256) public referralCredits;
    mapping(address => uint256) public axiesRewarded;
    uint256 public totalAxiesRewarded;

    event AxiesAdopted(
        address indexed adopter,
        uint8 indexed clazz,
        uint256 quantity,
        address indexed referrer
    );

    event AxiesRewarded(address indexed receiver, uint256 quantity);

    event AdoptedAxiesRedeemed(
        address indexed receiver,
        uint8 indexed clazz,
        uint256 quantity
    );
    event RewardedAxiesRedeemed(address indexed receiver, uint256 quantity);

    constructor() {
        priceIncrements[CLASS_BEAST] = priceIncrements[
            CLASS_AQUATIC
        ] = priceIncrements[CLASS_PLANT] = INITIAL_PRICE_INCREMENT; //

        currentPrices[CLASS_BEAST] = currentPrices[
            CLASS_AQUATIC
        ] = currentPrices[CLASS_PLANT] = INITIAL_PRICE; //
    }

    function axiesPrice(
        uint256 beastQuantity,
        uint256 aquaticQuantity,
        uint256 plantQuantity
    ) public view returns (uint256 totalPrice) {
        uint256 price;

        (price, , ) = _axiesPrice(CLASS_BEAST, beastQuantity);
        totalPrice = totalPrice.add(price);

        (price, , ) = _axiesPrice(CLASS_AQUATIC, aquaticQuantity);
        totalPrice = totalPrice.add(price);

        (price, , ) = _axiesPrice(CLASS_PLANT, plantQuantity);
        totalPrice = totalPrice.add(price);
    }

    function adoptAxies(
        uint256 beastQuantity,
        uint256 aquaticQuantity,
        uint256 plantQuantity,
        address referrer
    ) public payable whenNotPaused {
        require(
            block.timestamp <= PRESALE_END_TIMESTAMP,
            "block.timestamp <= PRESALE_END_TIMESTAMP"
        );

        require(beastQuantity <= 3, "beastQuantity <= 3");
        require(aquaticQuantity <= 3, "aquaticQuantity <= 3");
        require(plantQuantity <= 3, "plantQuantity <= 3");

        address adopter = msg.sender;
        address actualReferrer = address(0);

        // An adopter cannot be his/her own referrer.
        if (referrer != adopter) {
            actualReferrer = referrer;
        }

        uint256 value = msg.value;
        uint256 price;

        if (beastQuantity > 0) {
            price = _adoptAxies(
                adopter,
                CLASS_BEAST,
                beastQuantity,
                actualReferrer
            );

            require(value >= price, "1: value >= price");
            value -= price;
        }

        if (aquaticQuantity > 0) {
            price = _adoptAxies(
                adopter,
                CLASS_AQUATIC,
                aquaticQuantity,
                actualReferrer
            );

            require(value >= price, "2: value >= price");
            value -= price;
        }

        if (plantQuantity > 0) {
            price = _adoptAxies(
                adopter,
                CLASS_PLANT,
                plantQuantity,
                actualReferrer
            );

            require(value >= price, "3: value >= price");
            value -= price;
        }

        payable(msg.sender).transfer(value);

        // The current referral is ignored if the referrer's address is 0x0.

        if (actualReferrer != address(0)) {
            uint256 numCredit = referralCredits[actualReferrer]
                .add(beastQuantity)
                .add(aquaticQuantity)
                .add(plantQuantity);

            uint256 numReward = numCredit / REF_CREDITS_PER_AXIE;

            if (numReward > 0) {
                referralCredits[actualReferrer] =
                    numCredit %
                    REF_CREDITS_PER_AXIE;
                axiesRewarded[actualReferrer] = axiesRewarded[actualReferrer]
                    .add(numReward);
                totalAxiesRewarded = totalAxiesRewarded.add(numReward);
                emit AxiesRewarded(actualReferrer, numReward);
            } else {
                referralCredits[actualReferrer] = numCredit;
            }
        }
    }

    function redeemAdoptedAxies(
        address receiver,
        uint256 beastQuantity,
        uint256 aquaticQuantity,
        uint256 plantQuantity
    )
        public
        onlyOwner
        returns (
            uint256 /* remainingBeastQuantity */,
            uint256 /* remainingAquaticQuantity */,
            uint256 /* remainingPlantQuantity */
        )
    {
        return (
            _redeemAdoptedAxies(receiver, CLASS_BEAST, beastQuantity),
            _redeemAdoptedAxies(receiver, CLASS_AQUATIC, aquaticQuantity),
            _redeemAdoptedAxies(receiver, CLASS_PLANT, plantQuantity)
        );
    }

    function redeemRewardedAxies(
        address receiver,
        uint256 quantity
    ) public onlyOwner returns (uint256 remainingQuantity) {
        remainingQuantity = axiesRewarded[receiver] = axiesRewarded[receiver]
            .sub(quantity);

        if (quantity > 0) {
            // This requires that rewarded Axies are always included in the total
            // to make sure overflow won't happen.
            totalAxiesRewarded -= quantity;

            emit RewardedAxiesRedeemed(receiver, quantity);
        }
    }

    /**
     * @dev Calculate price of Axies from the same class.
     * @param clazz The class of Axies.
     * @param quantity Number of Axies to be calculated.
     */
    function _axiesPrice(
        uint8 clazz,
        uint256 quantity
    )
        private
        view
        returns (
            uint256 totalPrice,
            uint256 priceIncrement,
            uint256 currentPrice
        )
    {
        priceIncrement = priceIncrements[clazz];
        currentPrice = currentPrices[clazz];

        uint256 nextPrice;

        for (uint256 i = 0; i < quantity; i++) {
            totalPrice = totalPrice.add(currentPrice);
            nextPrice = currentPrice.add(priceIncrement);

            if (nextPrice / 0.1 ether != currentPrice / 0.1 ether) {
                priceIncrement >>= 1;
            }

            currentPrice = nextPrice;
        }
    }

    /**
     * @dev Adopt some Axies from the same class.
     * @param adopter Address of the adopter.
     * @param clazz The class of adopted Axies.
     * @param quantity Number of Axies to be adopted, this should be positive.
     * @param referrer Address of the referrer.
     */
    function _adoptAxies(
        address adopter,
        uint8 clazz,
        uint256 quantity,
        address referrer
    ) private returns (uint256 totalPrice) {
        (
            totalPrice,
            priceIncrements[clazz],
            currentPrices[clazz]
        ) = _axiesPrice(clazz, quantity);

        axiesAdopted[adopter][clazz] = axiesAdopted[adopter][clazz].add(
            quantity
        );
        totalAxiesAdopted[clazz] = totalAxiesAdopted[clazz].add(quantity);

        emit AxiesAdopted(adopter, clazz, quantity, referrer);
    }

    /**
     * @dev Redeem adopted Axies from the same class.
     * @param receiver Address of the receiver.
     * @param clazz The class of adopted Axies.
     * @param quantity Number of adopted Axies to be redeemed.
     */
    function _redeemAdoptedAxies(
        address receiver,
        uint8 clazz,
        uint256 quantity
    ) private returns (uint256 remainingQuantity) {
        remainingQuantity = axiesAdopted[receiver][clazz] = axiesAdopted[
            receiver
        ][clazz].sub(quantity);

        if (quantity > 0) {
            // This requires that adopted Axies are always included in the total
            // to make sure overflow won't happen.
            totalAxiesAdopted[clazz] -= quantity;

            emit AdoptedAxiesRedeemed(receiver, clazz, quantity);
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
