import React, { useState } from "react";
import {
    BrowserRouter,
    Routes,
    Route,
    Navigate,
    useNavigate,
} from "react-router-dom";

import PatientHomePage from "./pages/PatientHomePage";
import LoginPage from "./features/auth/presentation/screens/LoginScreen";
import "./styles.css";

function AppContent() {
    const navigate = useNavigate();

    const [user, setUser] = useState(() => {
        try {
            const savedUser = localStorage.getItem("bms_user");
            return savedUser ? JSON.parse(savedUser) : null;
        } catch {
            return null;
        }
    });

    const handleLoginSuccess = (data) => {
        localStorage.setItem("bms_access_token", data.accessToken);
        localStorage.setItem("bms_refresh_token", data.refreshToken);
        localStorage.setItem("bms_user", JSON.stringify(data.user));
setUser(data.user);
navigate("/", { replace: true });

    };

    const handleLogout = () => {
        localStorage.removeItem("bms_access_token");
        localStorage.removeItem("bms_refresh_token");
        localStorage.removeItem("bms_user");


setUser(null);
navigate("/", { replace: true });


    };

    return ( <Routes>
        <Route
            path="/"
            element={
                <PatientHomePage
                    user={user}
                    onLogin={() => navigate("/login")}
                    onLogout={handleLogout}
                />
            }
        />


        <Route
            path="/login"
            element={
                user ? (
                    <Navigate to="/" replace />
                ) : (
                    <LoginPage onLoginSuccess={handleLoginSuccess} />
                )
            }
        />

        <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>

);
}

export default function App() {
return ( <BrowserRouter> <AppContent /> </BrowserRouter>
);
}
