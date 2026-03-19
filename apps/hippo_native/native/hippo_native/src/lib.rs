use rustler::{NifStruct};

#[derive(Debug, NifStruct, Clone)]
#[module = "HippoNative.WelfordState"]
pub struct WelfordState {
    pub count: u64,
    pub mean: f64,
    pub m2: f64,
}

#[rustler::nif]
pub fn init_state() -> WelfordState {
    WelfordState {
        count: 0,
        mean: 0.0,
        m2: 0.0,
    }
}

#[rustler::nif]
pub fn update_and_get_z_score(state: WelfordState, new_value: f64) -> (WelfordState, f64) {
    let mut next_state = state;
    next_state.count += 1;

    let delta = new_value - next_state.mean;
    next_state.mean += delta / (next_state.count as f64);

    let delta2 = new_value - next_state.mean;
    next_state.m2 += delta * delta2;

    let variance = if next_state.count < 2 {
        0.0
    } else {
        next_state.m2 / (next_state.count as f64)
    };

    let std_dev = variance.sqrt();

    // Calculate Z-Score (how many standard deviations from the mean)
    let z_score = if std_dev > 0.0 {
        (new_value - next_state.mean).abs() / std_dev
    } else {
        0.0
    };

    (next_state, z_score)
}

rustler::init!("Elixir.HippoNative.Native");
