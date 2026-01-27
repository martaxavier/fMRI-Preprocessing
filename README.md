# fMRI-Preprocessing

Shell-based fMRI preprocessing and denoising pipelines used to compare the effect of different noise-removal strategies on the identification of resting-state networks (RSNs).

The repository implements multiple preprocessing and denoising variants based on motion regression, ICA-based cleanup (ICA-FIX), physiological signal regression, and their combinations.

Preprocessing outputs are used for group- and subject-level ICA analyses, followed by template matching with standard RSN's templates (Smith et al., 2009; Yeo et al, 2011). 

---

## Pipeline overview

The workflow is organized into three main stages: dataset configuration, preprocessing and denoising, and RSN extraction and evaluation.

### 1. Dataset and pipeline configuration
- Edit `settings_dataset.sh` to define dataset-specific parameters.
- Define dataset, task, run and denoise pipeline in `main1.sh` and `main2.sh`.

### 2. Preprocessing and denoising
- Run `main1.sh` to perform initial (minimal) preprocessing.
- Classify unknown ICA components returned by ICA-FIX and edit the corresponding `.txt` file in the `mel.ica` output directory.
- Edit and run `main2.sh` to select and apply the denoising pipeline and registration options.

Supported denoising steps include:
- Minimal preprocessing baseline:
      - B0 distortion correction,
      - Motion realignment,
      - Spatial smoothing,
      - High-pass temporal filtering
- Motion realignment parameter regression
- Motion outlier regression
- ICA-based denoising using ICA-FIX
- Regression of cerebrospinal fluid (CSF) and white matter (WM) signals
- Single- and multi-stage nuisance regression strategies

### 3. ICA and RSN analysis
- Perform ICA:
  - Group ICA: `perform_group_ica.sh` (preferred)
  - Single-session ICA: `perform_singlesession_ica.sh`
- Match ICA components to reference RSN templates:
  - Group ICA: `perform_group_ica2.sh` (define the reference RSN template)
  - Single-session ICA: `compute_dice.sh` (define the reference RSN template)
- Extract RSN features:
  - Group ICA: `extract_rsns_group_features.sh`
  - Single-session ICA: `extract_rsns_features.sh`

All scripts are intended to be opened and edited to define input variables prior to execution.

---

## Software dependencies

All preprocessing, denoising, registration, and ICA steps in this repository are implemented using tools from (FMRIB Software Library) and executed via shell scripting.
