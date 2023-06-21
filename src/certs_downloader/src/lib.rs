use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Write;

pub struct Config {
    api_url: String,
    username: String,
    password: String,
    nonce: String,
    directory: String,
    part_subdir: Option<String>,
    id_ca_subdir: Option<String>,
    perm_ca_subdir: Option<String>,
}

impl Config {
    pub fn build(args: &Vec<String>) -> Result<Config, String> {
        if args.len() < 6 {
            let usage_msg = format!("Usage: cargo run <url> <username> <password> <nonce> <dir> [part_dir] [id_ca_dir] [perm_ca_dir]\n\
                                     With:\n\
                                     {0: <15} API URL of the DDS Permission Manager (DPM)\n\
                                     {1: <15} Username of the application in DPM\n\
                                     {2: <15} Password of the application in DPM\n\
                                     {3: <15} A nonce string\n\
                                     {4: <15} Top level directory to store the docs\n\
                                     {5: <15} Subdirectory to store docs specific to this participant (optional)\n\
                                     {6: <15} Subdirectory to store identity CA doc (optional)\n\
                                     {7: <15} Subdirectory to store permission CA doc (optional)",
                                    "<url>", "<username>", "<password>", "<nonce>", "<dir>", "[part_dir]", "[id_ca_dir]", "[perm_ca_dir]");
            return Err(usage_msg);
        }
        let part_subdir_arg = if args.len() >= 7 {
            Some(args[6].clone())
        } else {
            None
        };
        let id_ca_subdir_arg = if args.len() >= 8 {
            Some(args[7].clone())
        } else {
            None
        };
        let perm_ca_subdir_arg = if args.len() >= 9 {
            Some(args[8].clone())
        } else {
            None
        };
        Ok(Config {
            api_url: args[1].clone(),
            username: args[2].clone(),
            password: args[3].clone(),
            nonce: args[4].clone(),
            directory: args[5].clone(),
            part_subdir: part_subdir_arg,
            id_ca_subdir: id_ca_subdir_arg,
            perm_ca_subdir: perm_ca_subdir_arg,
        })
    }
}

#[derive(Serialize, Deserialize)]
struct KeyPair {
    private: String,
    public: String,
}

pub fn download_certs(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::builder().cookie_store(true).build().unwrap();
    let login_url = format!("{}/login", config.api_url);
    let credential = format!(
        "{{\"username\":\"{}\", \"password\":\"{}\"}}",
        config.username, config.password
    );
    let _auth_resp = client
        .post(login_url)
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body(credential)
        .send();

    let base_url = format!("{}/applications", config.api_url);
    let id_ca_dir = format!(
        "{}/{}",
        config.directory,
        if config.id_ca_subdir.is_some() {
            config.id_ca_subdir.clone().unwrap()
        } else {
            String::from("")
        }
    );
    let perm_ca_dir = format!(
        "{}/{}",
        config.directory,
        if config.perm_ca_subdir.is_some() {
            config.perm_ca_subdir.clone().unwrap()
        } else {
            String::from("")
        }
    );
    let part_dir = format!(
        "{}/{}",
        config.directory,
        if config.part_subdir.is_some() {
            config.part_subdir.clone().unwrap()
        } else {
            String::from("")
        }
    );
    download_cert(&client, &base_url, "identity_ca.pem", None, &id_ca_dir)?;
    download_cert(&client, &base_url, "permissions_ca.pem", None, &perm_ca_dir)?;
    download_cert(&client, &base_url, "governance.xml.p7s", None, &config.directory)?;
    download_cert(&client, &base_url, "key_pair", Some(&config.nonce), &config.directory)?;
    download_cert(&client, &base_url, "permissions.xml.p7s", Some(&config.nonce), &part_dir)?;

    let kp_file = format!("{}/key_pair", config.directory);
    let kp_str = fs::read_to_string(&kp_file)?;
    let kp: KeyPair = serde_json::from_str(&kp_str)?;

    let public_file = format!("{}/identity.pem", part_dir);
    let private_file = format!("{}/identity_key.pem", part_dir);
    fs::File::create(public_file)?.write_all(kp.public.as_bytes())?;
    fs::File::create(private_file)?.write_all(kp.private.as_bytes())?;
    fs::remove_file(&kp_file)?;
    Ok(())
}

fn download_cert(
    client: &Client,
    base_url: &str,
    filename: &str,
    nonce: Option<&str>,
    directory: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let url;
    if nonce.is_some() {
        url = format!("{}/{}?nonce={}", base_url, filename, nonce.unwrap());
    } else {
        url = format!("{}/{}", base_url, filename);
    }
    let body = client.get(&url).send()?.text()?;

    let path = format!("{}/{}", directory, filename);
    fs::create_dir_all(directory)?;
    let mut file = fs::File::create(path)?;
    file.write_all(body.as_bytes())?;
    Ok(())
}
