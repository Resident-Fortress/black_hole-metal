#include "../include/black_hole_cuda.h"
#include <iostream>
#include <chrono>
#include <string>
#include <fstream>
#include <sstream>

class CudaCameraController {
private:
    glm::vec3 target = glm::vec3(0.0f, 0.0f, 0.0f);
    float radius = 6.34194e10f;
    float minRadius = 1e10f, maxRadius = 1e12f;
    float azimuth = 0.0f;
    float elevation = M_PI / 2.0f;
    float orbitSpeed = 0.01f;
    float zoomSpeed = 25e9f;
    bool dragging = false;
    bool moving = false;
    double lastX = 0.0, lastY = 0.0;

public:
    CudaCamera getCamera(int width, int height) {
        CudaCamera cam;
        
        // Calculate position
        float clampedElevation = glm::clamp(elevation, 0.01f, float(M_PI) - 0.01f);
        cam.position = glm::vec3(
            radius * sin(clampedElevation) * cos(azimuth),
            radius * cos(clampedElevation),
            radius * sin(clampedElevation) * sin(azimuth)
        );
        
        // Calculate camera vectors
        glm::vec3 forward = glm::normalize(target - cam.position);
        glm::vec3 worldUp = glm::vec3(0.0f, 1.0f, 0.0f);
        glm::vec3 right = glm::normalize(glm::cross(forward, worldUp));
        glm::vec3 up = glm::normalize(glm::cross(right, forward));
        
        cam.forward = forward;
        cam.right = right;
        cam.up = up;
        cam.aspect = float(width) / float(height);
        cam.tanHalfFov = tan(glm::radians(60.0f) * 0.5f);
        cam.moving = moving;
        
        return cam;
    }
    
    void processMouseMove(double x, double y) {
        if (!dragging) return;
        
        float dx = float(x - lastX);
        float dy = float(y - lastY);
        
        azimuth += dx * orbitSpeed;
        elevation -= dy * orbitSpeed;
        elevation = glm::clamp(elevation, 0.01f, float(M_PI) - 0.01f);
        
        lastX = x;
        lastY = y;
        moving = true;
    }
    
    void processMouseButton(int button, int action, GLFWwindow* win) {
        if (button == GLFW_MOUSE_BUTTON_LEFT) {
            if (action == GLFW_PRESS) {
                dragging = true;
                glfwGetCursorPos(win, &lastX, &lastY);
                moving = true;
            } else if (action == GLFW_RELEASE) {
                dragging = false;
                moving = false;
            }
        }
    }
    
    void processScroll(double xoffset, double yoffset) {
        radius -= float(yoffset) * zoomSpeed;
        radius = glm::clamp(radius, minRadius, maxRadius);
        moving = true;
    }
    
    void processKey(int key, int scancode, int action, int mods) {
        if (action == GLFW_PRESS) {
            switch(key) {
                case GLFW_KEY_R:
                    // Reset camera
                    radius = 6.34194e10f;
                    azimuth = 0.0f;
                    elevation = M_PI / 2.0f;
                    std::cout << "[INFO] Camera reset" << std::endl;
                    break;
                case GLFW_KEY_P:
                    // Cycle through presets
                    static int preset = 0;
                    preset = (preset + 1) % 3;
                    switch(preset) {
                        case 0:
                            radius = 6.34194e10f;
                            azimuth = 0.0f;
                            elevation = M_PI / 2.0f;
                            std::cout << "[INFO] Equatorial view" << std::endl;
                            break;
                        case 1:
                            radius = 8.0e10f;
                            azimuth = 0.0f;
                            elevation = 0.3f;
                            std::cout << "[INFO] Polar view" << std::endl;
                            break;
                        case 2:
                            radius = 3.0e10f;
                            azimuth = M_PI / 4.0f;
                            elevation = M_PI / 3.0f;
                            std::cout << "[INFO] Close-up view" << std::endl;
                            break;
                    }
                    break;
            }
            moving = true;
        }
    }
};

class CudaRenderer {
private:
    GLFWwindow* window;
    GLuint textureId;
    GLuint vao, vbo;
    GLuint shaderProgram;
    
    cudaGraphicsResource* cudaResource;
    float4* d_output;
    
    int width, height;
    
    AccretionDisk disk;
    BlackHole blackHole;
    CudaCameraController cameraController;
    
    void initOpenGL() {
        // Initialize GLFW
        if (!glfwInit()) {
            throw std::runtime_error("Failed to initialize GLFW");
        }
        
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        
        window = glfwCreateWindow(width, height, "CUDA Black Hole Ray Tracer", nullptr, nullptr);
        if (!window) {
            glfwTerminate();
            throw std::runtime_error("Failed to create GLFW window");
        }
        
        glfwMakeContextCurrent(window);
        
        // Initialize GLEW
        if (glewInit() != GLEW_OK) {
            throw std::runtime_error("Failed to initialize GLEW");
        }
        
        // Set up callbacks
        glfwSetWindowUserPointer(window, this);
        
        glfwSetMouseButtonCallback(window, [](GLFWwindow* win, int button, int action, int mods) {
            CudaRenderer* renderer = static_cast<CudaRenderer*>(glfwGetWindowUserPointer(win));
            renderer->cameraController.processMouseButton(button, action, win);
        });
        
        glfwSetCursorPosCallback(window, [](GLFWwindow* win, double x, double y) {
            CudaRenderer* renderer = static_cast<CudaRenderer*>(glfwGetWindowUserPointer(win));
            renderer->cameraController.processMouseMove(x, y);
        });
        
        glfwSetScrollCallback(window, [](GLFWwindow* win, double xoffset, double yoffset) {
            CudaRenderer* renderer = static_cast<CudaRenderer*>(glfwGetWindowUserPointer(win));
            renderer->cameraController.processScroll(xoffset, yoffset);
        });
        
        glfwSetKeyCallback(window, [](GLFWwindow* win, int key, int scancode, int action, int mods) {
            CudaRenderer* renderer = static_cast<CudaRenderer*>(glfwGetWindowUserPointer(win));
            renderer->cameraController.processKey(key, scancode, action, mods);
        });
        
        // Create texture
        glGenTextures(1, &textureId);
        glBindTexture(GL_TEXTURE_2D, textureId);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        GL_CHECK();
        
        // Create fullscreen quad
        float vertices[] = {
            -1.0f, -1.0f, 0.0f, 0.0f,
             1.0f, -1.0f, 1.0f, 0.0f,
             1.0f,  1.0f, 1.0f, 1.0f,
            -1.0f, -1.0f, 0.0f, 0.0f,
             1.0f,  1.0f, 1.0f, 1.0f,
            -1.0f,  1.0f, 0.0f, 1.0f
        };
        
        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
        glEnableVertexAttribArray(1);
        GL_CHECK();
        
        // Create shader program
        shaderProgram = createShaderProgram();
    }
    
    GLuint createShaderProgram() {
        const char* vertexShaderSource = R"(
            #version 330 core
            layout (location = 0) in vec2 aPos;
            layout (location = 1) in vec2 aTexCoord;
            out vec2 TexCoord;
            void main() {
                gl_Position = vec4(aPos, 0.0, 1.0);
                TexCoord = aTexCoord;
            }
        )";
        
        const char* fragmentShaderSource = R"(
            #version 330 core
            out vec4 FragColor;
            in vec2 TexCoord;
            uniform sampler2D screenTexture;
            void main() {
                FragColor = texture(screenTexture, TexCoord);
            }
        )";
        
        GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vertexShader, 1, &vertexShaderSource, nullptr);
        glCompileShader(vertexShader);
        
        GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fragmentShader, 1, &fragmentShaderSource, nullptr);
        glCompileShader(fragmentShader);
        
        GLuint program = glCreateProgram();
        glAttachShader(program, vertexShader);
        glAttachShader(program, fragmentShader);
        glLinkProgram(program);
        
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        
        return program;
    }
    
    void initCUDA() {
        // Initialize CUDA
        CUDA_CHECK(cudaSetDevice(0));
        
        // Register OpenGL texture with CUDA
        CUDA_CHECK(cudaGraphicsGLRegisterImage(&cudaResource, textureId, GL_TEXTURE_2D, 
                                              cudaGraphicsMapFlagsWriteDiscard));
        
        // Allocate device memory for output
        CUDA_CHECK(cudaMalloc(&d_output, width * height * sizeof(float4)));
        
        std::cout << "[INFO] CUDA initialized successfully" << std::endl;
        
        // Print GPU info
        cudaDeviceProp prop;
        CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
        std::cout << "[INFO] GPU: " << prop.name << std::endl;
        std::cout << "[INFO] Compute Capability: " << prop.major << "." << prop.minor << std::endl;
        std::cout << "[INFO] Global Memory: " << prop.totalGlobalMem / (1024*1024) << " MB" << std::endl;
    }
    
public:
    CudaRenderer(int w, int h) : width(w), height(h) {
        // Initialize black hole parameters
        blackHole.position = glm::vec3(0.0f, 0.0f, 0.0f);
        blackHole.mass = 8.54e36f; // Sagittarius A*
        blackHole.schwarzschildRadius = SAGA_RS;
        
        // Initialize accretion disk
        disk.innerRadius = SAGA_RS * 3.0f;     // 3x Schwarzschild radius
        disk.outerRadius = SAGA_RS * 20.0f;    // 20x Schwarzschild radius  
        disk.thickness = SAGA_RS * 0.1f;
        disk.temperature = 50000.0f;
        
        initOpenGL();
        initCUDA();
        
        std::cout << "[INFO] CUDA Black Hole Renderer initialized" << std::endl;
        std::cout << "[INFO] Controls:" << std::endl;
        std::cout << "[INFO]   Mouse drag: Rotate camera" << std::endl;
        std::cout << "[INFO]   Mouse wheel: Zoom" << std::endl;  
        std::cout << "[INFO]   R: Reset camera" << std::endl;
        std::cout << "[INFO]   P: Cycle camera presets" << std::endl;
        std::cout << "[INFO]   ESC: Exit" << std::endl;
    }
    
    ~CudaRenderer() {
        if (d_output) cudaFree(d_output);
        if (cudaResource) cudaGraphicsUnregisterResource(cudaResource);
        
        glDeleteProgram(shaderProgram);
        glDeleteBuffers(1, &vbo);
        glDeleteVertexArrays(1, &vao);
        glDeleteTextures(1, &textureId);
        
        glfwDestroyWindow(window);
        glfwTerminate();
    }
    
    void run() {
        auto startTime = std::chrono::high_resolution_clock::now();
        int frameCount = 0;
        
        while (!glfwWindowShouldClose(window)) {
            glfwPollEvents();
            
            if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS) {
                glfwSetWindowShouldClose(window, true);
            }
            
            // Get current time for animation
            auto currentTime = std::chrono::high_resolution_clock::now();
            float time = std::chrono::duration<float>(currentTime - startTime).count();
            
            // Get camera parameters
            CudaCamera camera = cameraController.getCamera(width, height);
            
            // Launch CUDA kernel
            launchPhotorealisticKernel(d_output, camera, disk, blackHole, width, height, time);
            CUDA_CHECK(cudaDeviceSynchronize());
            
            // Map CUDA resource to OpenGL
            CUDA_CHECK(cudaGraphicsMapResources(1, &cudaResource, 0));
            
            cudaArray* cuArray;
            CUDA_CHECK(cudaGraphicsSubResourceGetMappedArray(&cuArray, cudaResource, 0, 0));
            
            // Copy CUDA output to OpenGL texture
            CUDA_CHECK(cudaMemcpy2DToArray(cuArray, 0, 0, d_output, 
                                          width * sizeof(float4), width * sizeof(float4), height, 
                                          cudaMemcpyDeviceToDevice));
            
            CUDA_CHECK(cudaGraphicsUnmapResources(1, &cudaResource, 0));
            
            // Render fullscreen quad
            glClear(GL_COLOR_BUFFER_BIT);
            glUseProgram(shaderProgram);
            glBindTexture(GL_TEXTURE_2D, textureId);
            glBindVertexArray(vao);
            glDrawArrays(GL_TRIANGLES, 0, 6);
            
            glfwSwapBuffers(window);
            
            // FPS counter
            frameCount++;
            if (frameCount % 60 == 0) {
                auto now = std::chrono::high_resolution_clock::now();
                float elapsed = std::chrono::duration<float>(now - startTime).count();
                float fps = frameCount / elapsed;
                std::cout << "[INFO] FPS: " << fps << std::endl;
            }
        }
    }
};

int main() {
    try {
        std::cout << "=== CUDA Black Hole Ray Tracer ===" << std::endl;
        std::cout << "Photorealistic GPU-accelerated black hole simulation" << std::endl;
        std::cout << "Optimized for NVIDIA RTX 4060 8GB" << std::endl;
        std::cout << "=====================================\n" << std::endl;
        
        CudaRenderer renderer(1200, 900);
        renderer.run();
        
    } catch (const std::exception& e) {
        std::cerr << "[ERROR] " << e.what() << std::endl;
        return -1;
    }
    
    return 0;
}