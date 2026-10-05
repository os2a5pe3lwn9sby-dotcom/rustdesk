// CI builds of this fork carry FORK_BUILD (the workflow run number) and look
// for a newer "<platform>-b<N>" release of the fork instead of asking
// api.rustdesk.com, so the app never offers to replace itself with upstream.

use crate::hbbs_http::create_http_client_async;
use hbb_common::{tls::TlsType, ResultType};
use serde_derive::Deserialize;

const RELEASES_API: &str =
    "https://api.github.com/repos/os2a5pe3lwn9sby-dotcom/rustdesk/releases?per_page=50";

#[derive(Deserialize)]
struct Release {
    tag_name: String,
    html_url: String,
    #[serde(default)]
    draft: bool,
}

pub fn current_build() -> Option<u64> {
    option_env!("FORK_BUILD").and_then(|v| v.parse().ok())
}

fn tag_prefix() -> &'static str {
    if cfg!(target_os = "android") {
        "android-b"
    } else if cfg!(target_os = "macos") {
        "macos-b"
    } else {
        "unsupported-b"
    }
}

/// The release page URL of a newer build, if any.
pub async fn newer_release_url(current: u64) -> ResultType<Option<String>> {
    let client = create_http_client_async(TlsType::Rustls, false);
    let bytes = client
        .get(RELEASES_API)
        .header("User-Agent", "rustdesk-fork-updater")
        .header("Accept", "application/vnd.github+json")
        .send()
        .await?
        .error_for_status()?
        .bytes()
        .await?;
    let releases: Vec<Release> = serde_json::from_slice(&bytes)?;
    let newest = releases
        .into_iter()
        .filter(|r| !r.draft)
        .filter_map(|r| {
            let n = r.tag_name.strip_prefix(tag_prefix())?.parse::<u64>().ok()?;
            Some((n, r.html_url))
        })
        .max_by_key(|(n, _)| *n);
    Ok(newest.filter(|(n, _)| *n > current).map(|(_, url)| url))
}
