my $password_domain = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_";
my $password_length = 15;
my $key_file = "key";
my $store_file = "store";


# get master password
my $master_password = prompt_for_password();


# if key is not initiated, create new key
`touch ./$key_file.gpg`;
my $key = `cat ./$key_file.gpg`;

if ($key eq "") {
    # get random number from hardware noise
    my $random = `od -vAn -j 10 -N 256 -x < /dev/random`;
    $random =~ s/\s//g;
    $key = $random;
    `echo $random | tee ./$key_file`;

    # encrypt the key file
    `printf $master_password | gpg --batch --yes --cipher-algo AES256 --symmetric --passphrase-fd 0 ./$key_file`;

    # remove plain key file
    `rm ./$key_file`;

    # create store file and encrypt
    `touch ./$store_file`;
    `printf $master_password | gpg --batch --yes --cipher-algo AES256 --symmetric --passphrase-fd 0 ./$store_file`;

    # remove plain store file
    `rm ./$store_file`;

    print "new key is generated in ./$key_file.gpg\nKEY: $random\n";
    print "\nIMPORTANT! YOU MUST HAVE A BACKUP FOR THIS KEY, ";
    print "IF YOU LOST THIS KEY, ALL YOUR PASSWORDS ARE LOST. THIS KEY IS USED FOR SALTING YOUR PASSWORDS.\n";
} else {
    # decrypt the key.gpg
    $key = `printf $master_password | gpg --batch --yes --passphrase-fd 0 --decrypt ./$key_file.gpg`;

    if ($key eq "") {
        print "INVALID PASSWORD\n";
        exit;
    }
}



# arg '-a' means add new domain:username
my $command = @ARGV[0];


if ($command eq "-a" or $command eq "--add") {
    my $domain = @ARGV[1];

    # decrypt the key.gpg (master_password must be correct at this point)
    `printf $master_password | gpg --batch --yes --passphrase-fd 0 --output ./$store_file --decrypt ./$store_file.gpg`;

    # check if it is already exist
    my $same_domain = `cat ./$store_file | grep $domain`;

    if ($same_domain ne "") {
        print "$same_domain is already exist\n";

        # remove plain store file
        `rm ./$store_file`;

        exit;
    }

    # store to file, but don't store hashed password since it is
    # recoverable. Store onaly domains
    `echo $domain | tee -a ./$store_file`;

    # remove ./$store_file.gpg
    `rm ./$store_file.gpg`;

    # encrypt the store file
    `printf $master_password | gpg --batch --yes --cipher-algo AES256 --symmetric --passphrase-fd 0 ./$store_file`;

    # remove plain store file
    `rm ./$store_file`;

    print "$domain is added successfully\n"


} elsif ($command eq "ls" or $command eq "--list") {

    # decrypt the key.gpg (master_password must be correct at this point)
    `printf $master_password | gpg --batch --yes --passphrase-fd 0 --output ./$store_file --decrypt ./$store_file.gpg`;

    # print all saved domains/passwords if any
    print `cat ./$store_file`;

     # remove plain store file
    `rm ./$store_file`;


} elsif ($command eq "-g" or $command eq "--generate") {
    # salt the master password with the domain
    my $domain = @ARGV[1];
    my $salted_password = $domain . ":" . $master_password . ":" . $key;


    # hash using sha256 (sha256sum)
    my $hash_algorithm = "sha256sum";
    my $hashed_seed = `printf "$salted_password" | $hash_algorithm`;
    my $hashed_seed = substr($hashed_seed, 0, 8);

    srand(hex($hashed_seed));

    print "Password of $domain: ";
    for (my $i = 0; $i < $password_length; $i++) {
        my $r = int(rand(length($password_domain)));
        print substr($password_domain, $r, 1);
    }

    print "\n";
}







# https://stackoverflow.com/questions/39801195/how-can-perl-prompt-for-a-password-without-showing-it-in-the-terminal
sub prompt_for_password {
    require Term::ReadKey;

    # Tell the terminal not to show the typed chars
    Term::ReadKey::ReadMode('noecho');

    print "Type in your secret password: ";
    my $password = Term::ReadKey::ReadLine(0);

    # Rest the terminal to what it was previously doing
    Term::ReadKey::ReadMode('restore');

    # The one you typed didn't echo!
    print "\n";

    # get rid of that pesky line ending (and works on Windows)
    $password =~ s/\R\z//;

    # say "Password was <$password>"; # check what you are doing :)

    return $password;
}