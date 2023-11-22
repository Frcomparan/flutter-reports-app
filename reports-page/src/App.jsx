import { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [contacts, setContacts] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    axios('http://127.0.0.1:5000/reports')
      .then((response) => {
        setContacts(response.data);
        setError(null);
      })
      .catch(setError);
  }, []);

  if (error) return <p>Ha ocurrido un error</p>;

  return (
    <>
      <div className='content'>
        <div className='filter'>
          <label htmlFor=''>
            Tipo de evento
            <select class='form-control'>
              <option>Default select</option>
            </select>
          </label>
          <label htmlFor=''>
            Zona
            <select class='form-control'>
              <option>Default select</option>
            </select>
          </label>
          <label htmlFor=''>
            Fecha
            <select class='form-control'>
              <option>Recientes</option>
              <option>Antiguos</option>
            </select>
          </label>
        </div>
        <div className='table-responsive'>
          <table className='table table-hover'>
            <thead className='table-primary'>
              <tr>
                <th scope='col'>id</th>
                <th scope='col'>Descripción</th>
                <th scope='col'>Fecha de reporte</th>
                <th scope='col'>Ubicación</th>
                <th scope='col'>Referencia</th>
              </tr>
            </thead>
            <tbody>
              {contacts.map(
                ({ id, description, fecha, imagePath, location }) => (
                  <tr key={id}>
                    <th scope='row'>{id}</th>
                    <td>{description}</td>
                    <td>{fecha}</td>

                    <td>
                      <div className='centered-content'>
                        <a
                          className='icon-container'
                          href={`https://www.google.com.mx/maps/@${location},20z?entry=ttu`}
                        >
                          <i className='fa-solid fa-map-location-dot'></i>
                        </a>
                      </div>
                    </td>
                    <td>
                      <div className='centered-content'>
                        <div className='icon-container'>
                          <i className='fa-regular fa-image'></i>
                        </div>
                      </div>
                      {/* <img src={`../uploads/${imagePath}`} alt='' /> */}
                    </td>
                  </tr>
                )
              )}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}

export default App;
