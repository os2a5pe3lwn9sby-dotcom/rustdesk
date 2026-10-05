// Reads Mission Control Spaces per display through the private CGS API, the
// same one menu bar tools such as Spaceman use. Symbols are looked up at
// runtime so a macOS release without them disables the feature instead of
// failing to load.

use core_foundation::{
    array::{CFArrayGetCount, CFArrayGetTypeID, CFArrayGetValueAtIndex, CFArrayRef},
    base::{CFGetTypeID, CFRelease, CFTypeRef, TCFType},
    dictionary::{CFDictionaryGetTypeID, CFDictionaryGetValue, CFDictionaryRef},
    number::{kCFNumberSInt64Type, CFNumberGetTypeID, CFNumberGetValue, CFNumberRef},
    string::{CFString, CFStringGetTypeID, CFStringRef},
    uuid::{CFUUIDCreateString, CFUUIDRef},
};
use hbb_common::libc::{c_char, c_void, dlsym, RTLD_DEFAULT};

type MainConnectionIdFn = unsafe extern "C" fn() -> i32;
type CopyManagedDisplaySpacesFn = unsafe extern "C" fn(i32) -> CFArrayRef;
type DisplayCreateUuidFn = unsafe extern "C" fn(u32) -> CFUUIDRef;

unsafe fn symbol(name: &[u8]) -> *mut c_void {
    dlsym(RTLD_DEFAULT, name.as_ptr() as *const c_char)
}

unsafe fn get(dict: CFTypeRef, key: &str) -> CFTypeRef {
    if dict.is_null() || CFGetTypeID(dict) != CFDictionaryGetTypeID() {
        return std::ptr::null();
    }
    let key = CFString::new(key);
    CFDictionaryGetValue(
        dict as CFDictionaryRef,
        key.as_concrete_TypeRef() as *const c_void,
    )
}

unsafe fn to_string(v: CFTypeRef) -> Option<String> {
    if v.is_null() || CFGetTypeID(v) != CFStringGetTypeID() {
        return None;
    }
    Some(CFString::wrap_under_get_rule(v as CFStringRef).to_string())
}

unsafe fn to_i64(v: CFTypeRef) -> Option<i64> {
    if v.is_null() || CFGetTypeID(v) != CFNumberGetTypeID() {
        return None;
    }
    let mut out: i64 = 0;
    if CFNumberGetValue(
        v as CFNumberRef,
        kCFNumberSInt64Type,
        &mut out as *mut i64 as *mut c_void,
    ) {
        Some(out)
    } else {
        None
    }
}

unsafe fn items(v: CFTypeRef) -> Vec<CFTypeRef> {
    if v.is_null() || CFGetTypeID(v) != CFArrayGetTypeID() {
        return vec![];
    }
    let a = v as CFArrayRef;
    (0..CFArrayGetCount(a))
        .map(|i| CFArrayGetValueAtIndex(a, i) as CFTypeRef)
        .collect()
}

unsafe fn display_uuid(create: DisplayCreateUuidFn, display_id: u32) -> Option<String> {
    let uuid = create(display_id);
    if uuid.is_null() {
        return None;
    }
    let s = CFUUIDCreateString(std::ptr::null(), uuid);
    CFRelease(uuid as CFTypeRef);
    if s.is_null() {
        return None;
    }
    Some(CFString::wrap_under_create_rule(s).to_string())
}

/// `display_names` are RustDesk's display names, which on macOS are the
/// CGDirectDisplayIDs. Returns "index:count:current" per CGS display group,
/// comma separated, with index -1 when the group matches no RustDesk display
/// (e.g. "Main" when displays do not have separate Spaces).
pub fn spaces_summary(display_names: &[String]) -> Option<String> {
    unsafe {
        let main_conn = symbol(b"CGSMainConnectionID\0");
        let copy_spaces = symbol(b"CGSCopyManagedDisplaySpaces\0");
        let create_uuid = symbol(b"CGDisplayCreateUUIDFromDisplayID\0");
        if main_conn.is_null() || copy_spaces.is_null() || create_uuid.is_null() {
            return None;
        }
        let main_conn: MainConnectionIdFn = std::mem::transmute(main_conn);
        let copy_spaces: CopyManagedDisplaySpacesFn = std::mem::transmute(copy_spaces);
        let create_uuid: DisplayCreateUuidFn = std::mem::transmute(create_uuid);

        let uuids: Vec<Option<String>> = display_names
            .iter()
            .map(|n| {
                n.parse::<u32>()
                    .ok()
                    .and_then(|id| display_uuid(create_uuid, id))
            })
            .collect();

        let groups = copy_spaces(main_conn());
        if groups.is_null() {
            return None;
        }
        let mut parts = Vec::new();
        for group in items(groups as CFTypeRef) {
            let ident = to_string(get(group, "Display Identifier")).unwrap_or_default();
            let current = to_i64(get(get(group, "Current Space"), "ManagedSpaceID"));
            let spaces = items(get(group, "Spaces"));
            let pos = spaces
                .iter()
                .position(|s| to_i64(get(*s, "ManagedSpaceID")) == current && current.is_some())
                .map_or(-1, |p| p as i64);
            let index = uuids
                .iter()
                .position(|u| {
                    u.as_deref()
                        .map_or(false, |u| u.eq_ignore_ascii_case(&ident))
                })
                .map_or(-1, |i| i as i64);
            parts.push(format!("{}:{}:{}", index, spaces.len(), pos));
        }
        CFRelease(groups as CFTypeRef);
        Some(parts.join(","))
    }
}
