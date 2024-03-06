/*
* @file            : some change here.cls
* @brief           : Encapsulates the shape of a loyalty household within Salesforce
* @business-unit   : another change
* @feature-descr   : Love's Connect Summary
* @feature-id      : 375964
* 
* @description     : 
*		This class contains the shape of the household data we retrieve from an API, as well as the long to convert it to the shape we want
*       within Salesforce.
*/
public with sharing class lccLoyaltyHousehold {

    public final static integer TIREPASS_ID = 43;

    public Customer customer {get;set;}
    public Address address {get;set;}
    public List<Cards> cards {get;set;}
    public List<Segments> segments {get;set;}
    public List<Rewards> rewards {get;set;}
    public LoyaltySummary summary {get;set;}
    public RetalixHousehold retalixHousehold;

    public lccLoyaltyHousehold(RetalixHousehold household){
        retalixHousehold = household;
        this.mapCustomerAndCards();
        this.mapAddress();
        this.mapSegments();
        this.mapRewards();
        this.mapSummary();
        retalixHousehold = null;
    }

    /* converts the retalix data to the salesforce way */
    public static lccLoyaltyHousehold getHouseholdStructure(String householdString){
        if(String.isBlank(householdString)) return null;

        /* correct some data issues with raw retalix household data */
        householdString = replacePrimitiveJsonTypes(householdString);
        householdString = formatDatesAndDateTimes(householdString);

        /* transform the raw household into a defined class */
        RetalixHousehold retalixHousehold = (RetalixHousehold) JSON.deserialize(householdString, lccLoyaltyHousehold.RetalixHousehold.class);

        /* build the final structure we want */
        return new lccLoyaltyHousehold(retalixHousehold);
    }


    /* Replaces some reserved Apex words that Retalix is using. Do this before deserializing the Retalix response. */
    public static String replacePrimitiveJsonTypes(String aString) {
        aString = aString.replaceAll('\"number\"', '\"Digits\"');
        aString = aString.replaceAll('\"type\"', '\"Types\"');
        return aString;
    }

    /* alter the datetime format that retalix gives us */
    public static String formatDatesAndDateTimes(String aString) {
        //Retalix formats the Dates as '1950-11-01T00:00:00'. Salesforce wants these to be '1950-11-01'.
        aString = aString.replaceAll('T00:00:00', '');

        //Inject '.000Z' to the end of the remaining Datetime values so that salesforce will deserialize it properly. This is using positive lookbehind (?<=) and positive lookahead (?=)
        aString = aString.replaceAll('(?<=(\\d{2}:\\d{2}:\\d{2}))(\")(?=,)', '.000Z\"');
        return aString;
    }

    /* maps data from retalix to 'customer' structure and the 'cards' structure */
    private void mapCustomerAndCards(){
        this.customer = new Customer();
        this.cards = new List<Cards>();

        this.customer.retalixId     = String.valueOf(this.retalixHousehold.Id);
        this.customer.firstName     = this.retalixHousehold.Members[0].firstName;
        this.customer.lastName      = this.retalixHousehold.Members[0].lastName;
        this.customer.fullName      = this.customer.firstName + ' ' + this.customer.lastName;
        this.customer.email         = this.retalixHousehold.Members[0].emailAddress;
        this.customer.active        = this.retalixHousehold.Members[0].Status.Description == 'Active' ? true : false;
        this.customer.birthDate     = this.retalixHousehold.Members[0].DateOfBirth;
        this.customer.lovesId       = this.retalixHousehold.Members[0].CustomerPortalUserId;
        this.customer.tier          = this.retalixHousehold.Tier;

        /* grab the mobile phone number out of the array */
        for(RetalixPhoneNumbers phone : this.retalixHousehold.Members[0].phoneNumbers){
            if(phone.Types == 'Mobile'){
                this.customer.phoneNumber = phone.Digits;
                break;
            }
        }
        if(String.isBlank(this.customer.phoneNumber)) this.customer.phoneNumber = 'None';

        /* grab the active card number out of the array */
        for(RetalixAccounts card : this.retalixHousehold.Members[0].Accounts){
            Cards cardUpd = new Cards();
            cardUpd.cardNumber      = card.CardNumber;
            cardUpd.status          = card.Status;
            cardUpd.issueDate       = card.IssueDate;
            cardUpd.hasPumpStart    = card.HasPumpStart;
            
            this.cards.add(cardUpd);

            if(card.Status == 'Active') this.customer.activeCard = card.CardNumber;
        }
        if(String.isBlank(this.customer.activeCard)) this.customer.activeCard = 'No Active Card';

        /* grab fields from the summary array */
        for(RetalixSummary summ : this.retalixHousehold.Summary){
            if(summ.Key == 'Member Since') this.customer.memberSince = summ.Value;
            if(summ.Key == 'Last Visit') this.customer.lastVisit = summ.Value;
        }
        if(String.isBlank(this.customer.memberSince)) this.customer.memberSince = 'Unknown';
        if(String.isBlank(this.customer.lastVisit)) this.customer.lastVisit = 'Unknown';
    }

    /* maps data from retalix to 'address' structure */
    private void mapAddress(){
        this.address = new Address();
        this.address.address    = this.retalixHousehold.Members[0].Address.Address1;
        this.address.address2   = this.retalixHousehold.Members[0].Address.Address2;
        this.address.poBox      = this.retalixHousehold.Members[0].Address.POBox;
        this.address.postalCode = this.retalixHousehold.Members[0].Address.ZipCode;
        this.address.city       = this.retalixHousehold.Members[0].Address.City ?? 'Unknown';
        this.address.state      = this.retalixHousehold.Members[0].Address.State.Name;
        this.address.country    = this.retalixHousehold.Members[0].Address.Country.Name;
        if(String.isBlank(this.address.state)) this.address.cityState = this.address.city;
        else this.address.cityState = this.address.city + ', ' + this.address.state;
    }

    /* maps data from retalix to 'segments' structure */
    private void mapSegments(){
        this.segments = new List<Segments>();
        for(RetalixSegments seg : this.retalixHousehold.Segments){
            Segments segUpd = new Segments();
            segUpd.id               = seg.Id;
            segUpd.key              = seg.Key;
            segUpd.name             = seg.Name;
            segUpd.active           = seg.Status == 'Active' ? true : false;
            segUpd.attachmentSource = seg.AttachmentSource;
            this.segments.add(segUpd);
        }
    }

    /* maps data from retalix to 'rewards' structure */
    private void mapRewards(){
        this.rewards = new List<Rewards>();
        for(RetalixBalances rew : this.retalixHousehold.Balances){
            Rewards rewUpd = new Rewards();
            rewUpd.id       = rew.Id;
            rewUpd.key      = rew.InternalKey;
            rewUpd.name     = rew.Name;
            rewUpd.value    = rew.Value;
            this.rewards.add(rewUpd);
        }
    }

    /* maps data from retalix to 'summary' structure */
    private void mapSummary(){
        
        /* group tier buckets together into sets */
        Set<Integer> showerRewardIds = new Set<Integer>();
        Set<Integer> drinkRewardIds = new Set<Integer>();
        Set<Integer> gallonsRewardIds = new Set<Integer>();
        Set<Integer> pointsRewardIds = new Set<Integer>();
        for(MLR_Tier__c tierSettings : getTierInfo()){
            if(tierSettings.ShowerRewardId__c != null) showerRewardIds.add(Integer.valueOf(tierSettings.ShowerRewardId__c));
            if(tierSettings.DrinkRewardId__c != null) drinkRewardIds.add(Integer.valueOf(tierSettings.DrinkRewardId__c));
            if(tierSettings.GallonsRewardId__c != null) gallonsRewardIds.add(Integer.valueOf(tierSettings.GallonsRewardId__c));
            if(tierSettings.PointsRewardId__c != null) pointsRewardIds.add(Integer.valueOf(tierSettings.PointsRewardId__c));
        }

        /* build the summary */
        this.summary = new LoyaltySummary();
        this.summary.drinks = 0;
        this.summary.gallons = 0;
        this.summary.points = 0;
        this.summary.showers = 0;
        this.summary.tirepass = 0;
        for(RetalixBalances rew : this.retalixHousehold.Balances){
            if(drinkRewardIds.contains(rew.Id)) this.summary.drinks += Integer.valueOf(rew.Value);
            if(showerRewardIds.contains(rew.Id)) this.summary.showers += Integer.valueOf(rew.Value);
            if(gallonsRewardIds.contains(rew.Id)) this.summary.gallons += Integer.valueOf(rew.Value);
            if(pointsRewardIds.contains(rew.Id)) this.summary.points += Integer.valueOf(rew.Value);
            if(rew.Id == TIREPASS_ID) this.summary.tirepass = Integer.valueOf(rew.Value);
        }
    }

    /* structure definitions */
    public class Customer{ 
        @AuraEnabled public String retalixId {get;set;}
        @AuraEnabled public String birthDate {get;set;}
        @AuraEnabled public String firstName {get;set;}
        @AuraEnabled public String lastName {get;set;}
        @AuraEnabled public String fullName {get;set;}
        @AuraEnabled public String email {get;set;}
        @AuraEnabled public String phoneNumber {get;set;}
        @AuraEnabled public Boolean active {get;set;}
        @AuraEnabled public String activeCard {get;set;}
        @AuraEnabled public String lovesId {get;set;}
        @AuraEnabled public String memberSince {get;set;}
        @AuraEnabled public String lastVisit {get;set;}
        @AuraEnabled public String tier {get;set;} 
    }

    public class Address{ 
        @AuraEnabled public String address {get;set;}
        @AuraEnabled public String address2 {get;set;}
        @AuraEnabled public String poBox {get;set;}
        @AuraEnabled public String postalCode {get;set;}
        @AuraEnabled public String city {get;set;}
        @AuraEnabled public String state {get;set;}
        @AuraEnabled public String country {get;set;}
        @AuraEnabled public String cityState {get;set;}
    }
    public class Cards{
        @AuraEnabled public String cardNumber {get;set;}
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public Boolean hasPumpStart {get;set;}
        @AuraEnabled public String issueDate {get;set;}
    }
    
    public class Rewards{
        @AuraEnabled public Integer id {get;set;}
        @AuraEnabled public Integer key {get;set;}
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public Decimal value {get;set;}
    }
    public class Segments{
        @AuraEnabled public Integer id {get;set;}
        @AuraEnabled public Integer key {get;set;}
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public Boolean active {get;set;}
        @AuraEnabled public String attachmentSource {get;set;}
    }

    public class LoyaltySummary{
        @AuraEnabled public Integer gallons {get;set;}
        @AuraEnabled public Integer points {get;set;}
        @AuraEnabled public Integer drinks {get;set;}
        @AuraEnabled public Integer showers {get;set;}
        @AuraEnabled public Integer tirepass {get;set;}
    }
    
    public static List<MLR_Tier__c> getTierInfo(){
        return [SELECT Name, Tier_Min_Gallon__c, Tier_Max_Gallon__c, Tier_Points__c, PointsRewardId__c, ShowerRewardId__c, GallonsRewardId__c, DrinkRewardId__c FROM MLR_Tier__c];
    }

    public class RetalixHousehold {
        @AuraEnabled public Integer Id;
        @AuraEnabled public List<RetalixMembers> Members;
        @AuraEnabled public List<RetalixBalances> Balances;
        @AuraEnabled public List<RetalixSegments> Segments;
        @AuraEnabled public List<RetalixSummary> Summary;
        @AuraEnabled public String Tier;
        @AuraEnabled public String NextTier;
        @AuraEnabled public String Original;
        @AuraEnabled public Decimal CurrentTierStartingPoints;
        @AuraEnabled public Decimal NextTierStartingPoints;
        @AuraEnabled public Decimal TierProgressPercentage;
    }

    public class RetalixMembers {
		@AuraEnabled public Integer Id;
		@AuraEnabled public String DateOfBirth;
		@AuraEnabled public String RewardMemberStartDate;
		@AuraEnabled public String FirstName;
		@AuraEnabled public String LastName;
		@AuraEnabled public String DriversLicenseNumber;
		@AuraEnabled public List<RetalixAccounts> Accounts;
		@AuraEnabled public String Types;
		@AuraEnabled public String Remarks;
		@AuraEnabled public Boolean HasPlatinumStatus;
		@AuraEnabled public Boolean HasPlatinumPlusStatus;
		@AuraEnabled public Boolean IsEligibleForPlatinumStatus;
		@AuraEnabled public RetalixAddress Address;
		@AuraEnabled public String EmailAddress;
		@AuraEnabled public Boolean ReceiveEmailOffers;
		@AuraEnabled public Boolean ReceiveTextOffers;
		@AuraEnabled public Boolean ReceiveTobaccoOffers;
		@AuraEnabled public String PortalUserId;
		@AuraEnabled public Integer RedemptionPrivileges;
		@AuraEnabled public String CompanyName;
		@AuraEnabled public String CdlNumber;
		@AuraEnabled public Boolean ReceivePhoneOffers;
		@AuraEnabled public String CustomerPortalUserId;
		@AuraEnabled public RetalixStatus Status;
		@AuraEnabled public List<RetalixPhoneNumbers> phoneNumbers;
		@AuraEnabled public String EstimatedNumberOfTrucks;
		@AuraEnabled public Boolean ReceiveFuelOffers;
	}

    public class RetalixBalances {
		@AuraEnabled public Integer Id;
		@AuraEnabled public Integer InternalKey;
		@AuraEnabled public String Name;
		@AuraEnabled public String NameWithoutTier;
		@AuraEnabled public String Reason;
    @AuraEnabled public String Icon;
    @AuraEnabled public Boolean DisplayTier;
    @AuraEnabled public Boolean isHiddenWhenZero;
		@AuraEnabled public String LastUpdateDate;
		@AuraEnabled public String ExpirationDate;
		@AuraEnabled public Decimal Value;
		@AuraEnabled public Decimal LastValueIncrement;
		@AuraEnabled public Decimal TotalAccumulatedValue;
		@AuraEnabled public Decimal TotalRedeemedValue;
	}

    public class RetalixSegments {
		@AuraEnabled public Integer Id;
		@AuraEnabled public Integer Key;
		@AuraEnabled public Boolean IsShared;
		@AuraEnabled public String Name;
		@AuraEnabled public String Reason;
		@AuraEnabled public String Status;
		@AuraEnabled public String ClubEntity;
		@AuraEnabled public String AttachmentSource;
		@AuraEnabled public Boolean IsAttached;
		@AuraEnabled public String LastUpdate;
	}

    public class RetalixSummary {
		@AuraEnabled public String Key;
		@AuraEnabled public String Value;
	}

    public class RetalixAccounts {
		@AuraEnabled public String CardNumber;
		@AuraEnabled public Boolean HasPumpStart;
		@AuraEnabled public String Status;
		@AuraEnabled public String StatusReason;
		@AuraEnabled public Integer PointBalance;
		@AuraEnabled public Integer ShowerCredits;
		@AuraEnabled public Integer TirePassCredits;
		@AuraEnabled public Integer DrinkRefills;
		@AuraEnabled public Integer PointsSubjectToExpiration;
		@AuraEnabled public Decimal GallonsToPlatinum;
		@AuraEnabled public Decimal GallonsToGold;
		@AuraEnabled public Decimal GallonsToDiamond;
		@AuraEnabled public Decimal GallonsMonthToDate;
		@AuraEnabled public String LastStoreVisited;
		@AuraEnabled public String IssueDate;
		@AuraEnabled public String ExpirationDate;
		@AuraEnabled public String LastDateTimeUsed;
	}

    public class RetalixPhoneNumbers {
		@AuraEnabled public String Digits;
		@AuraEnabled public String Types;
	}

    public class RetalixAddress {
		@AuraEnabled public String Address1;
		@AuraEnabled public String Address2;
		@AuraEnabled public String StreetNumber;
		@AuraEnabled public String ZipCode;
		@AuraEnabled public String POBox;
		@AuraEnabled public String City;
		@AuraEnabled public RetalixState State;
		@AuraEnabled public String Types;
		@AuraEnabled public RetalixState Country;

		public String getAddressAsFormattedString() {
			String format = '{0},\n' + (!String.isBlank(Address2) ? '{1}\n' : '') + (!String.isBlank(POBox) ? '\n{2}' : '') + '{3}, {4} {5}\n{6}';
			List<String> addressFields = new String[] { Address1, Address2, POBox, City, State.Name, ZipCode, Country.Name };
			return String.format(format, addressFields);
		}
	}

    public class RetalixState {
		@AuraEnabled public String Id;
		@AuraEnabled public String Name;
	}

    public class RetalixStatus {
		@AuraEnabled public Integer Id;
		@AuraEnabled public String Description;
	}
}