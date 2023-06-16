use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::io::Write;

struct Parameters {
    api_url: String,
    username: String,
    password: String,
    nonce: String,
    directory: String,
    part_subdir: String,
    id_ca_subdir: String,
    perm_ca_subdir: String,
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 9 {
        println!("Usage: cargo run <url> <username> <password> <nonce> <dir> <part_dir> <id_ca_dir> <perm_ca_dir>");
        println!("With:");
        println!("{0: <15} API URL of the DDS Permission Manager (DPM)", "<url>");
        println!("{0: <15} Username of the application in DPM", "<username>");
        println!("{0: <15} Password of the application in DPM", "<password>");
        println!("{0: <15} A nonce string", "<nonce>");
        println!("{0: <15} Top level directory to store the docs", "<dir>");
        println!("{0: <15} Subdirectory to store docs specific to this participant", "<part_dir>");
        println!("{0: <15} Subdirectory to store identity CA doc", "<id_ca_dir>");
        println!("{0: <15} Subdirectory to store permission CA doc", "<perm_ca_dir>");
        return;
    }
    let para = Parameters {
        api_url: args[1].clone(),
        username: args[2].clone(),
        password: args[3].clone(),
        nonce: args[4].clone(),
        directory: args[5].clone(),
        part_subdir: args[6].clone(),
        id_ca_subdir: args[7].clone(),
        perm_ca_subdir: args[8].clone(),
    };

    let result = download_certs(&para);
    match result {
        Ok(_) => (),
        Err(err) => {
            println!("download_certs failed: {:?}", err);
        }
    }
}

#[derive(Serialize, Deserialize)]
struct KeyPair {
    private: String,
    public: String,
}

fn download_certs(para: &Parameters) -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::builder().cookie_store(true).build().unwrap();
    let login_url = format!("{}/login", para.api_url);
    let credential = format!(
        "{{\"username\":\"{}\", \"password\":\"{}\"}}",
        para.username, para.password
    );
    let _auth_resp = client
        .post(login_url)
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body(credential)
        .send();

    let base_url = format!("{}/applications", para.api_url);
    let id_ca_dir = format!("{}/{}", para.directory, para.id_ca_subdir);
    let perm_ca_dir = format!("{}/{}", para.directory, para.perm_ca_subdir);
    download_cert(
        &client,
        &base_url,
        "identity_ca.pem",
        None,
        &id_ca_dir,)?;
    download_cert(
        &client,
        &base_url,
        "permissions_ca.pem",
        None,
        &perm_ca_dir,
    )?;
    download_cert(
        &client,
        &base_url,
        "governance.xml.p7s",
        None,
        &para.directory,
    )?;
    download_cert(
        &client,
        &base_url,
        "key_pair",
        Some(&para.nonce),
        &para.directory,
    )?;
    let part_dir = format!("{}/{}", para.directory, para.part_subdir);
    download_cert(
        &client,
        &base_url,
        "permissions.xml.p7s",
        Some(&para.nonce),
        &part_dir,
    )?;

    let kp_file = format!("{}/key_pair", para.directory);
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
