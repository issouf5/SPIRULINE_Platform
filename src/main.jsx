
import React from 'react';
import {createRoot} from 'react-dom/client';
import App from './App.jsx';
import './styles.css';
class Boundary extends React.Component{state={failed:false};static getDerivedStateFromError(){return {failed:true};}render(){return this.state.failed?<main className="center"><h1>Impossible d’afficher cet écran</h1><p>Vos données enregistrées restent dans votre espace.</p><button onClick={()=>location.reload()}>Recharger</button></main>:this.props.children;}}
createRoot(document.getElementById('root')).render(<Boundary><App/></Boundary>);
