
# Choose the machine you are running on. Currently only SCIAMA2 is implemented, but it's easy to add more :)
# ==========================================================================================================
#MACHINE = SCIAMA2
#MACHINE = RAIJIN
#MACHINE = PLEIADES
#MACHINE = PAWSEY
#MACHINE = g2
MACHINE = LAPTOP

# Options for optimization
# ========================
OPTIMIZE  = -O3

# Various C preprocessor directives that change the way L-PICOLA is made
# ====================================================================
#SINGLE_PRECISION = -DSINGLE_PRECISION   # Single precision floats and FFTW (else use double precision)
#OPTIONS += $(SINGLE_PRECISION)

MEMORY_MODE = -DMEMORY_MODE               # Save memory by making sure to allocate and deallocate arrays only when needed
OPTIONS += $(MEMORY_MODE)                 # and by making the particle data single precision

PARTICLE_ID = -DPARTICLE_ID               # Assigns unsigned long long IDs to each particle and outputs them
OPTIONS += $(PARTICLE_ID)

#LIGHTCONE = -DLIGHTCONE                  # Builds a lightcone based on the run parameters and only outputs particles
#OPTIONS += $(LIGHTCONE)                  # at a given timestep if they have entered the lightcone

#ONLY_ZA = -DONLY_ZA                      # Uncomment to force ZA initial conditions (2LPT otherwise)
#OPTIONS += $(ONLY_ZA)

GADGET_STYLE = -DGADGET_STYLE             # Write snapshot outputs in Gadget-1 style format
OPTIONS += $(GADGET_STYLE)                # Incompatible with LIGHTCONE simulations

#UNFORMATTED = -DUNFORMATTED              # Binary output for LIGHTCONE simulations
#OPTIONS += $(UNFORMATTED)

#TIMING = -DTIMING                        # Turns on timing loops throughout the code
#OPTIONS += $(TIMING)

# ----------------------
# Initial condition configuration
# ----------------------

IC_TYPE ?= GAUSSIAN
RAND_SOURCE ?= INTERNAL

IC_TYPE := $(strip $(IC_TYPE))
RAND_SOURCE := $(strip $(RAND_SOURCE))

# IC_TYPE defines the statistical model of the initial conditions:
#   GAUSSIAN      → standard Gaussian initial conditions
#   LOCAL_FNL     → local-type primordial non-Gaussianity
#   EQUIL_FNL     → equilateral-type non-Gaussianity
#   ORTHO_FNL     → orthogonal-type non-Gaussianity
#   GENERIC_FNL   → generic kernel-based implementation
#
# Note: when RAND_SOURCE=EXTERNAL, the statistical properties are defined
# by the input field itself. In this case, IC_TYPE still controls which
# code branch is compiled, but it is not the primary physical descriptor.

# RAND_SOURCE defines how the random field is generated:
#   INTERNAL → standard internal Gaussian random number generation
#   EXTERNAL → random field is read from file (activates RANDOM_NUMBER_FILE)

# Executable name
ifeq ($(RAND_SOURCE),EXTERNAL)
  EXEC = build/L-PICOLA_IC_EXTERNAL
else
  EXEC = build/L-PICOLA_$(IC_TYPE)_$(RAND_SOURCE)
endif

# ----------------------
# Statistical model
# ----------------------
ifeq ($(IC_TYPE),GAUSSIAN)
  GAUSSIAN = -DGAUSSIAN
  OPTIONS += $(GAUSSIAN)
endif

ifeq ($(IC_TYPE),LOCAL_FNL)
  LOCAL_FNL = -DLOCAL_FNL
  OPTIONS += $(LOCAL_FNL)
endif

ifeq ($(IC_TYPE),EQUIL_FNL)
  EQUIL_FNL = -DEQUIL_FNL
  OPTIONS += $(EQUIL_FNL)
endif

ifeq ($(IC_TYPE),ORTHO_FNL)
  ORTHO_FNL = -DORTHO_FNL
  OPTIONS += $(ORTHO_FNL)
endif

ifeq ($(IC_TYPE),GENERIC_FNL)
  GENERIC_FNL = -DGENERIC_FNL
  OPTIONS += $(GENERIC_FNL)
endif

# ----------------------
# Random source
# ----------------------
ifeq ($(RAND_SOURCE),EXTERNAL)
  RANDOM_NUMBER_FILE = -DRANDOM_NUMBER_FILE
  OPTIONS += $(RANDOM_NUMBER_FILE)
endif

# Setup libraries
# Here is where you'll need to add the correct filepaths for the libraries
ifeq ($(MACHINE),LAPTOP)
  CC = mpicc
  FFTW_INCL = -I/usr/local/include/
  FFTW_LIBS = -L/usr/local/lib/ -lfftw3_mpi -lfftw3
  GSL_INCL  = -I/usr/local/include/gsl/
  GSL_LIBS  = -L/usr/local/lib/ -lgsl -lgslcblas
  MPI_INCL  = -I/usr/local/include/openmpi/
  MPI_LIBS  = -L/usr/local/lib/openmpi/  -lmpi
endif

# Run some checks on option compatibility
# =======================================

# --- Sanity checks for Makefile configuration ---
VALID_IC_TYPES = GAUSSIAN LOCAL_FNL EQUIL_FNL ORTHO_FNL GENERIC_FNL
ifneq ($(filter $(IC_TYPE),$(VALID_IC_TYPES)),$(IC_TYPE))
  $(error ERROR: invalid IC_TYPE='$(IC_TYPE)'. Choose one of: $(VALID_IC_TYPES))
endif

VALID_RAND_SOURCES = INTERNAL EXTERNAL
ifneq ($(filter $(RAND_SOURCE),$(VALID_RAND_SOURCES)),$(RAND_SOURCE))
  $(error ERROR: invalid RAND_SOURCE='$(RAND_SOURCE)'. Choose one of: $(VALID_RAND_SOURCES))
endif

# --- Existing compatibility checks ---
ifdef PARTICLE_ID
ifdef LIGHTCONE
  $(warning WARNING: LIGHTCONE output does not output particle IDs)
endif
endif

ifdef GADGET_STYLE
ifdef LIGHTCONE
  $(error ERROR: LIGHTCONE and GADGET_STYLE are not compatible; for binary output with LIGHTCONE simulations choose UNFORMATTED instead)
endif
endif

ifdef UNFORMATTED
ifndef LIGHTCONE
  $(error ERROR: UNFORMATTED is incompatible with snapshot simulations; for binary snapshot output choose GADGET_STYLE instead)
endif
endif

# --- External random-field checks ---
ifdef RANDOM_NUMBER_FILE
ifdef LIGHTCONE
  $(warning WARNING: RANDOM_NUMBER_FILE has not been specifically tested together with LIGHTCONE)
endif
ifdef SINGLE_PRECISION
  $(warning WARNING: RANDOM_NUMBER_FILE with SINGLE_PRECISION should be validated carefully)
endif
  $(warning WARNING: RANDOM_NUMBER_FILE input has not yet been fully validated in parallel mode)
endif

ifeq ($(RAND_SOURCE),EXTERNAL)
ifneq ($(IC_TYPE),GAUSSIAN)
  $(warning WARNING: RAND_SOURCE=EXTERNAL with IC_TYPE=$(IC_TYPE) should be validated carefully)
endif
endif

# Compile the code
# ================
LIBS   =   -lm $(MPI_LIBS) $(FFTW_LIBS) $(GSL_LIBS)

CFLAGS =   $(OPTIMIZE) $(FFTW_INCL) $(GSL_INCL) $(MPI_INCL) $(OPTIONS)

OBJS   = src/main.o src/cosmo.o src/auxPM.o src/2LPT.o src/power.o src/vars.o src/read_param.o
ifdef GENERIC_FNL
OBJS += src/kernel.o
endif
ifdef LIGHTCONE
OBJS += src/lightcone.o
endif

INCL   = src/vars.h src/proto.h Makefile

all: build $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) $(LIBS) -o $(EXEC)

build:
	mkdir -p build

clean:
	rm -f src/*.o src/*~ *~ build/L-PICOLA_*
