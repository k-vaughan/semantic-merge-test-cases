public class UsernameService {

    public UsernameService(Account acct) {
      userDetails = new UserDetails();
      address = new Address(acct);
    }
}