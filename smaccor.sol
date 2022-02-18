// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

// ---------------------- Built with 💘 for everyone --------------------------
/// @author Kinois Le Roi
/// @title SmACV1 [Smart Ads Contract V1] - This contract enables addresses to deploy smart ads.
/// Token : Paid Per Click - The winning crypto of the internet.
/// Symbol : PPeC - Spelled [P:E:K]
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
/// @title PPeC : Paid Per Click [ERC20] Interface
// ----------------------------------------------------------------------------
interface PPeC {
    /// Transfer `amount` tokens to `to`.
    function transfer(address to, uint256 amount) external returns (bool);

    /// Get the amount of tokens owned by account `owner`.
    function balanceOf(address owner) external view returns(uint256);

    /// Get treasury address.
    function treasury() external view returns(address);

    /// Get founder address.
    function founder() external view returns(address);
}

// ----------------------------------------------------------------------------
/// @title AdCreator : Smart Ads Contract Creator [SmACCor] - Enables addresses to publish Ads.
/// @notice Smart Ads cannot be updated once promoted.
// ----------------------------------------------------------------------------
contract AdCreator {

    // Define public constant variables.
    address PPeCAddress = 0xE1498556390645cA488320fe979bC72BdecB6A57; // PPeC contract address.
    address public founder; // PPeC founder address.
    address public treasury; // PPeC treasury address.
    uint256 public minClaimerBalance; // The minimum balance an address must have before claiming rewards.
    uint256 public minReward; // The minimum reward a promoter will offer to a claimer.
    uint256 public promoterFee; // Fee for ad space a promoter must pay [in % | 100 = 1%].
    uint256 public claimerFee; // Fee a claimer must pay [in % | 100 = 1%].
    bool public paused = false; // Advertisement publishing status.
    mapping(address => uint256) public pledged; // Total pledged balance of an address.
    mapping(address => bool) public delegateContract; // Delegate status of a contract.
    mapping(address => SmACV1[]) public promoterAds; // All ads for a given address.
    SmACV1[] public advertisements; // All ads.    
    
    // Set immutable values.
    constructor(uint256 minReward_, uint256 minBalance_) {
        founder = PPeC(PPeCAddress).founder();
        treasury = PPeC(PPeCAddress).treasury();
        minClaimerBalance = minBalance_;
        minReward = minReward_;
        promoterFee = 2000;
        claimerFee = 5000;
    }

    // Events that will be emitted on changes.    
    event Pause();
    event Unpause();
    event RemoveAd();
    event LaunchAd(
        string link, 
        string title, 
        uint256 reach, 
        uint256 reward, 
        uint256 budget, 
        uint256 indexed created,
        address indexed promoter, 
        address indexed adsContract
    );

    // Errors that describe failures.

    // The triple-slash comments are so-called natspec
    // comments. They will be shown when the user
    // is asked to confirm a transaction or
    // when an error is displayed. (source: solidity.org)

    /// The budget exceeds your balance.
    /// Your budget is `budget`, however your balance is `balance`.
    error BudgetExceedBalance(uint256 budget, uint256 balance);
    /// Your balance pledged `pledged` cannot exceeds your balance `balance`.
    error PledgeExceedBalance(uint256 pledged, uint256 balance);
    /// Your reward `reward` is lower than (`minReward`) the minimum required.
    error RewardTooLow(uint256 reward, uint256 minReward);
    /// The index entered `index` is out of bound.
    error IndexOutOfBound(uint256 index);
    /// You are not a delegate Contract.
    error NotDelegateContract();

    /// Make a function callable only when the contract is not paused.
    modifier whenNotPaused() {
        require(paused == false, "All publications have been paused.");
        _;
    }

    /// Make a function callable only when the contract is paused.
    modifier whenPaused() {
        require(paused);
        _;
    }

    /// Make a function callable only by the founder.
    modifier onlyFounder() {
        require(msg.sender == founder, "Your are not the Founder.");
        _;
    }

    /// Launch a smart advertisement.
    function launchAd(string memory title, string memory link, uint256 reach, uint256 reward)
    whenNotPaused
    public
    returns(bool success) 
    {
        // Require to reach at least 30 people.
        require(reach >= 30, "You must enter at least 30.");

        // Check promoter's [token] balance and pledged balance.
        // NOTE - Always check balances before transaction.
        uint256 PromoterBalance = PPeC(PPeCAddress).balanceOf(msg.sender);
        uint256 balancePledged = pledged[msg.sender];  

        // Set the budget.
        uint256 budget = reach * reward;
        
        // Revert the call if the budget required
        // is greater than the current balance.
        if (budget > PromoterBalance)
            revert BudgetExceedBalance(budget, PromoterBalance); 

        // Revert the call if the balance pledged
        // will be greater than the current balance.
        // This requirement makes it harder for an address 
        // to publish multiple ads. [more tokens = more ads] 
        if (balancePledged + budget > PromoterBalance)
            revert PledgeExceedBalance(balancePledged, PromoterBalance);

        // Revert the call if the reward offered is 
        // less than the minimum reward required.
        if (reward < minReward)
            revert RewardTooLow(reward, minReward);

        // Increase sender pledged balance.   
        pledged[msg.sender] += budget; 
        
        // Create the advertisement (SmAC constructor).
        // Variable orders should match bellow with SmAC constructor !!important!!
        SmACV1 newAdvertisement = new SmACV1(
            msg.sender,
            PPeCAddress,
            link,
            title,
            reach,
            reward,
            minReward,
            claimerFee,
            promoterFee,
            minClaimerBalance
        );

        // 1. Add advertisement to array.
        advertisements.push(newAdvertisement);
        // 2. Add advertisement to the sender array.
        promoterAds[msg.sender].push(newAdvertisement);

        // Set the new contract as a delegate
        // enabling calls [from SmAC] to function updatePledged() [in SmACCor].
        delegateContract[address(newAdvertisement)] = true;
        
        // See {event LaunchAds}
        emit LaunchAd(
            link, 
            title, 
            reach, 
            reward, 
            budget, 
            block.timestamp,
            msg.sender, // promoter address
            address(newAdvertisement) //contract address
        );       
        return true;
    }
    
    /// Remove an advertisement from the array.
    function removeAd(uint256 index) public onlyFounder returns(bool removed) {
        // Revert the call if the index is 
        // greater than or equal to the array length.
        if (index >= advertisements.length)
            revert IndexOutOfBound(index);

        // Shift array indexes.
        for (uint256 i = index; i < advertisements.length - 1; i++) {
            advertisements[i] = advertisements[i + 1];
        }
        
        // Remove last advertisement from array.
        advertisements.pop(); 

        // See {event RemoveAd}
        emit RemoveAd(); 
        return true;
    }

    /// Update promoter's pledged balance (SmAC Contracts calls only).
    function updatePledged(address promoter, uint256 amount) public returns(bool success) {   
        // Revert the call if the sender is not 
        // a delegate contract address.
        if (delegateContract[msg.sender] != true)
            revert NotDelegateContract();

        // Update pledged balance.
        pledged[promoter] = amount; 
        return true;
    }

    /// Change minimum reward to `newMin`.
    function setMinReward(uint256 newMin) public onlyFounder returns(bool success) {
        // set new minReward
        minReward = newMin; 
        return true;
    }

    /// Change the minimum balance a claimer must have before claiming rewards to `newMin`.
    function setMinClaimerBalance(uint256 newMin) public onlyFounder returns(bool success) {        
        // set new minClaimerBalance
        minClaimerBalance = newMin; 
        return true;
    }

    /// Change promoters' fee to `newFee`.
    function setPromoterFee(uint256 newFee) public onlyFounder returns(bool success) {
        // set new promoterFee
        promoterFee = newFee; 
        return true;
    }

    /// Change claimers' fee to `newFee`.
    function setClaimerFee(uint256 newFee) public onlyFounder returns(bool success) {
        // set new claimerFee     
        claimerFee = newFee; 
        return true;
    }
    
    /// Pause advertisement publication.
    function pause() public onlyFounder whenNotPaused returns(bool success) {
        // Set pause
        paused = true; 
        
        // See {event Pause}        
        emit Pause(); 
        return true;
    }
    
    /// Unpause advertisement publication.
    function unpause() public  onlyFounder whenPaused returns(bool success) {
        // Unset pause
        paused = false; 

        // See {event Unpause}        
        emit Unpause();
        return true;
    }

    /// Get the number of advertisements in our array.
    function promotionCount() public view returns(uint256) {
        return advertisements.length; // promotions count.
    }

    /// Get the amount of tokens owned by account `owner`.
    function balanceOf(address owner) public view returns(uint256) {
        return PPeC(PPeCAddress).balanceOf(owner);
    }

    /// Get the number of advertisements for `promoter`.
    function promoterAdCount(address promoter) public view returns(uint256) {
        return promoterAds[promoter].length;
    }

    /// Get the balances and ad count of `owner`.
    function ownerInfo(address owner) public view returns(uint256 wallet, uint256 pledge, uint256 adCount) {
        return (
            PPeC(PPeCAddress).balanceOf(owner), // owner balance
            pledged[owner], // owner pledged balance
            promoterAds[owner].length // owner ad count
        );
    }

    /// Get the contract information.
    function contractInfo() public view returns(uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            PPeC(PPeCAddress).balanceOf(treasury), // treasury balance
            advertisements.length, // ad count
            minClaimerBalance, // minimum claimer balance
            promoterFee, // promoter fee
            claimerFee, // claimer fee
            minReward // minimum reward
        );
    }
}

// ----------------------------------------------------------------------------
/// @title SmACCor : AdCreator [Smart ads Contract Creator] Interface.
// ----------------------------------------------------------------------------
interface SmACCor {

    /// Update the promoter pledged balance [SmAC contracts calls only].
    function updatePledged(address promoter, uint256 amount) external returns(bool);

    /// Get promoter total pledged balance.
    function pledged(address owner) external view returns(uint256);
}

// ----------------------------------------------------------------------------
/// @title Advertisement : Defines the sturcture of an advertisement.
// ----------------------------------------------------------------------------
struct Advertisement {
    string link;
    string title;
    uint256 reach;
    uint256 reward;
    uint256 budget;
    uint256 created;
    uint256 expired;
    uint256 claimers;
    uint256 scamReport;
    address promoter;
}

// ----------------------------------------------------------------------------
/// @title SmACV1 : Smart Ads Contract [SmAC V1] Version 1.
// ----------------------------------------------------------------------------
contract SmACV1 {

    // Define public constant variables.
    address PPeCAddress; // PPeC contract address.
    address public adCreatorAddress; // AdCreator [SmACCoror] address.
    uint256 public minClaimerBalance; // Holds minimum claimer balance needed before claiming rewards.
    uint256 public minReward; // Holds minimum reward required for each claim.
    uint256 promoterFee; // fee
    uint256 claimerFee; // fee
    Advertisement public Ads; // Holds the advertisement.
    mapping(address => mapping(address => bool)) claimed; // Holds each address claim status.

    // Set immutable values.
    constructor(
        address eoa, // eoa [externaly owned account] | [msg.sender]
        address PPeCAddress_,
        string memory link_,
        string memory title_, 
        uint256 reach_,
        uint256 reward_,
        uint256 minReward_,
        uint256 claimerFee_,
        uint256 promoterFee_,
        uint256 minClaimerBalance_
        ) {            
            Ads.link  = link_;
            Ads.title = title_;
            Ads.promoter = eoa;
            Ads.reach =  reach_;
            Ads.budget = reach_ * reward_;
            Ads.reward =  reward_;
            Ads.created = block.timestamp;
            Ads.expired = Ads.created + 15 days;
            Ads.claimers = 0;
            Ads.scamReport = 0;
            minReward = minReward_;
            claimerFee = claimerFee_;
            PPeCAddress = PPeCAddress_;
            promoterFee = promoterFee_;
            adCreatorAddress = msg.sender;
            minClaimerBalance = minClaimerBalance_;
    }

    // Events that will be emitted on changes.
    event Scam();
    event Destroy();
    event ScamReport();
    event Claim(address indexed claimer, uint256 reward);
    event DelegateCleaner(address indexed claimer, uint256 reward);

    /// You have already claimed the reward.
    error Claimed();
    /// You do not have enough tokens to claim rewards.
    error NotEnoughTokens(uint256 minBalance, uint256 balance);
    /// Reward exceed coffer balance.
    error NotEnoughReward(uint256 reward, uint256 coffer);
    /// The promotion has expired.
    error PromotionEnded();
    /// The promotion has not expired.
    error PromotionRunning();
    /// The promoter refund/claim date has not passed.
    error CannotClean();

    /// @dev Make a function not callable by the founder nor the promoter.
    modifier notOwners() {
        require(msg.sender != Ads.promoter, "Your are the Promoter.");
        require(msg.sender != PPeC(PPeCAddress).founder(), "Your are the Founder.");
        _;
    }

    /// @dev Make a function callable only by the founder.
    modifier onlyFounder() {
        require(msg.sender == PPeC(PPeCAddress).founder(), "Your are not the Founder.");
        _;
    }

    /// @dev Make a function callable only by the promoter.
    modifier onlyPromoter() {
        require(msg.sender == Ads.promoter, "Your are not the Promoter.");
        _;
    }

    /// Claim rewards.
    // Before anyone can claim a reward, we must perform some checks:
    // 1. The promoter and the founded cannot claim rewards.
    // 2. A claimer can claim only once.
    // 3. A claimer must have a minimum amount of tokens.
    // 4. The coffer must have enough funds for the claim.
    // 5. The Ad have to be running, not expired.
    function claim() public notOwners {
        // Claimer balance.
        uint256 claimerBalance = PPeC(PPeCAddress).balanceOf(msg.sender); 
        // Claimer claim status.
        bool claimedStatus = claimed[address(this)][msg.sender]; 

        // Revert the call if the sender
        // already claimed the reward.
        if (claimedStatus == true)
            revert Claimed();

        // Revert the call if the sender does not have
        // the minimum balance required for claiming rewards.
        if (minClaimerBalance > claimerBalance)
            revert NotEnoughTokens(minClaimerBalance, claimerBalance);

        // Revert the call if the reward exceeds or the budget
        // the coffer balance.
        if (Ads.reward > cofferBalance() || Ads.reward > Ads.budget)
            revert NotEnoughReward(Ads.reward, cofferBalance());

        // Revert the call if the promotion is not running.
        if (block.timestamp > Ads.expired)
            revert PromotionEnded();

        // Set claimer status to true [ claimed ☑ ].
        claimed[address(this)][msg.sender] = true;
        // Increase claimers count.
        // Note: We only want to increase claimers count.
        Ads.claimers += 1;

        // Start the transfer.
        // see reusable function [_transfer(receiver, fee, reward, unPledged)]
        _transfer(msg.sender, claimerFee, Ads.reward, Ads.reward);

        // feedback.
        emit Claim(msg.sender, Ads.reward);
    }

    /// Claim leftover rewards after advertisement expires.
    // if/when an Ad did not run successfully for any reason
    // We want promoters to be able to claim their tokens back.
    // We have to make sure that the Ad has expired.
    function destroy() public onlyPromoter {
        // Revert the call if the promotion is still running.
        if (block.timestamp < Ads.expired)
            revert PromotionRunning();

        // Checking if the promoter over/under funded the contract.
        _extraTokenCheck(Ads.promoter, promoterFee, cofferBalance());  

        // feedback.
        emit Destroy();
    }

    /// Claim leftover tokens 4 days after advertisement expires,
    /// if the promoter fails to claim tokens from the expired advertisement.
    function delegateCleaner() public notOwners {
        // Revert the call if the promotion has
        // not passed 4 days AFTER expriration.
        if (block.timestamp < Ads.expired + 4 days)
            revert CannotClean();

        // Checking if the promoter over/under funded the contract.
        _extraTokenCheck(msg.sender, claimerFee, cofferBalance());  

        // feedback.
        emit DelegateCleaner(msg.sender, cofferBalance());
    }

    /// Empty the contract's tokens and make it harder for 
    /// the promoter to advertise.
    // We have a big surprise for scammers! loss of funds. Don't do it.
    // Refrain from scamming others, and abide by all community rules my friend!
    function scam() public onlyFounder returns (bool success) {
        // Update pledged balance [The amount is too large for scammers to scam again].
        SmACCor(adCreatorAddress).updatePledged(Ads.promoter, 10000000000E18);

        // Transfer tokens to the treasury.
        PPeC(PPeCAddress).transfer(PPeC(PPeCAddress).treasury(), cofferBalance());

        // Reset budget
        Ads.budget = 0;

        // feedbacks.
        emit Scam();
        return true;
    }

    /// Report this SmAC as a scam.
    function scamReport() public returns (bool reported) {
        // Claimer balance.
        uint256 claimerBalance = PPeC(PPeCAddress).balanceOf(msg.sender);
        // Claimer claim status.
        bool claimedStatus = claimed[address(this)][msg.sender]; 

        // Revert the call if the sender
        // already claimed the reward or 
        // reported the SmAC as a scam.
        if (claimedStatus == true)
            revert Claimed();

        // Revert the call if the sender does not have
        // the minimum balance required for claiming rewards.
        if (minClaimerBalance > claimerBalance)
            revert NotEnoughTokens(minClaimerBalance, claimerBalance);

        // Revert the call if the promotion is not running.
        if (block.timestamp > Ads.expired)
            revert PromotionEnded();

        // Set claimer status to true [ claimed ☑ ].
        // Scam Reporter cannot claim this reward.
        claimed[address(this)][msg.sender] = true;

        // Increase report count.
        Ads.scamReport += 1;

        // feedbacks.
        emit ScamReport();
        return true;
    }

    // Reusable function
    function _transfer(address receiver, uint256 fee, uint256 reward, uint256 unPledged)
    internal
    virtual
    returns(bool success)
    {
        // Let set fees for treasury and set receiver reward.
        uint256 treasuryShare = ((reward * 100) * fee) / 1000000; // fees
        uint256 receiverShare = reward - treasuryShare; // rewards
        // Set Pledged balance.
        uint256 pledged = SmACCor(adCreatorAddress).pledged(Ads.promoter); 

        // Update pledged balance.
        SmACCor(adCreatorAddress).updatePledged(Ads.promoter, pledged - unPledged);

        // Reduce budget
        Ads.budget -= unPledged;

        // Transfer tokens.
        PPeC(PPeCAddress).transfer(PPeC(PPeCAddress).treasury(), treasuryShare); // send to treasury.
        PPeC(PPeCAddress).transfer(receiver, receiverShare); // send to caller.

        return true;
    }

    // Reusable function
    // Since we do not have a way to limit the promoter
    // from funding a contract, we have to check for discrepancies.
    // These checks will help us reduce the pledged amount appropriately.
    // 1. Check if the promoter over funded the contract.
    // 2. Check if the promoter under funded the contract.
    // 3. Check if the promoter correctly funded the contract.
    function _extraTokenCheck(address receiver, uint256 fee, uint256 balance)
    internal
    virtual 
    {
        // set reward   
        uint256 reward;
        // set extraToken - promoter extra tokens.
        uint256 extraToken;
        // set pledge - reduces the pledged balance.
        uint256 pledge;
        
        // Check if the promoter sent more tokens
        // to the contract than the budget required. 
        if (balance > Ads.budget){
            // set the extra tokens to exclude from fees.
            extraToken = balance - Ads.budget;
            // remove the extra tokens from the reward.
            reward = balance - extraToken;
            // set the pledged amount to be reduced by.
            pledge = reward;
        } 
        // Check if the promoter sent less tokens
        // to the contract than the budget required. 
        else if (balance < Ads.budget) {
            // set the extra tokens to exclude from fees.
            extraToken = 0;
            // set the reward to the balance.
            reward = balance;
            // set the pledged amount to be reduced by.
            pledge = Ads.budget;
        }
        // The promoter correctly funded the contract.
        else {
            // set the reward
            reward = balance;
            // no extra reward detected
            extraToken = 0;
            // set pledge
            pledge = balance;
        }  

        // see reusable function [_transfer(receiver, fee, reward, pledge)]
        _transfer(receiver, fee, reward, pledge);

        // send the promoter the extra balance.
        PPeC(PPeCAddress).transfer(Ads.promoter, extraToken);
    }

    /// Get claimer's claim status.
    function claimStatus() public view returns(bool) {
        return claimed[address(this)][msg.sender];
    }   

    /// Get the contract [coffer] balance.
    function cofferBalance() public view returns(uint256) {
        return PPeC(PPeCAddress).balanceOf(address(this));
    }

    /// Get the promoter's pledged balance.
    function pledgedBalance() public view returns(uint256) {
        return SmACCor(adCreatorAddress).pledged(Ads.promoter); 
    }

    /// Get important advertisement information.
    function getInfo() 
    public 
    view 
    returns(string memory, string memory, uint256,  uint256, uint256, uint256, uint256, uint256, uint256,  uint256, bool, address)
    {
        return (
            Ads.title, // ad title
            Ads.link, // ad link  
            Ads.reach, // number of addresses to reward per click
            Ads.reward, // reward amount
            Ads.scamReport, // scam report count
            Ads.created, // created date
            Ads.expired, // expiration date
            Ads.claimers, // claimer count            
            Ads.budget, // budget amount
            PPeC(PPeCAddress).balanceOf(address(this)), // coffer balance
            claimed[address(this)][msg.sender], // sender claim status
            Ads.promoter // promoter address
        ); 
    }
}
