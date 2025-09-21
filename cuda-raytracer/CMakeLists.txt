cmake_minimum_required(VERSION 3.18)
project(BlackHoleCUDA LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Find required packages
find_package(CUDAToolkit REQUIRED)
find_package(GLEW REQUIRED)
find_package(glfw3 CONFIG REQUIRED)
find_package(glm CONFIG REQUIRED)
find_package(OpenGL REQUIRED)

# Enable CUDA separable compilation
set(CMAKE_CUDA_SEPARABLE_COMPILATION ON)

# Set CUDA architecture (adjust based on target GPU)
# RTX 4060 uses Compute Capability 8.9 (Ada Lovelace)
set(CMAKE_CUDA_ARCHITECTURES 89)

# Include directories
include_directories(include)
include_directories(${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES})

# Source files
set(SOURCES
    src/main.cpp
    src/camera.cpp
    src/renderer.cpp
    src/cuda_kernels.cu
    src/opengl_interop.cpp
)

# Create executable
add_executable(BlackHoleCUDA ${SOURCES})

# Link libraries
target_link_libraries(BlackHoleCUDA 
    PRIVATE 
    CUDA::cudart
    CUDA::cuda_driver
    glfw 
    GLEW::GLEW 
    glm::glm 
    OpenGL::GL
)

# Set CUDA flags for optimization
set_target_properties(BlackHoleCUDA PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
    CUDA_RESOLVE_DEVICE_SYMBOLS ON
)

# CUDA compiler flags
target_compile_options(BlackHoleCUDA PRIVATE 
    $<$<COMPILE_LANGUAGE:CUDA>:-O3 --use_fast_math -Xptxas -O3>
)

# Copy shaders to build directory
file(GLOB SHADERS "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*")
foreach(shader ${SHADERS})
    add_custom_command(TARGET BlackHoleCUDA POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${shader}
        $<TARGET_FILE_DIR:BlackHoleCUDA>/shaders/
    )
endforeach()